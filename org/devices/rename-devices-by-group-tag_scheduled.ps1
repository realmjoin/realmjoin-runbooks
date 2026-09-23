<#
    .SYNOPSIS
    Name Autopilot devices after their group tag and serial number

    .DESCRIPTION
    Builds the computer name of every Windows Autopilot device from a template of group tag and serial number, for example SITE01-7ABCD12. The name goes into the Autopilot record for the next Autopilot deployment. Enrolled devices whose Intune name differs are renamed through Intune and take the new name after a restart. Hybrid joined and personal devices are only reported. A dry run lists all changes without writing anything.

    .PARAMETER NameTemplate
    Pattern of the computer name. %GROUPTAG% is replaced by the Autopilot group tag and %SERIAL% by the serial number; other characters stay as typed. Letters, digits and hyphens only, 15 characters at most after replacement.

    .PARAMETER SerialTruncation
    Which end of the serial number is kept when the assembled name would exceed 15 characters; only the serial number is shortened. Keeping the end matches what Autopilot itself does with %SERIAL%.

    .PARAMETER GroupTagFilter
    Only devices with one of these Autopilot group tags, separated by commas; SITE1* matches every tag that starts with SITE1. Leave empty for all devices that have a group tag.

    .PARAMETER GroupTagExcludeFilter
    Devices with one of these Autopilot group tags are left alone, separated by commas; KIOSK* matches every tag that starts with KIOSK. Applied after the group tag filter. Leave empty to exclude nothing.

    .PARAMETER RenameEnrolledDevices
    Also rename devices that are already enrolled in Intune. When off, only the Autopilot record is updated and the name is applied at the next Autopilot deployment.

    .PARAMETER MaxChangesPerRun
    Stops after this many devices have been changed; 0 means no limit. Useful for a staged first run.

    .PARAMETER WhatIfMode
    Only logs what would change without writing anything.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "NameTemplate": {
                "DisplayName": "Name template"
            },
            "SerialTruncation": {
                "DisplayName": "When the name is too long",
                "Select": {
                    "Options": [
                        {
                            "Display": "Keep the end of the serial number",
                            "ParameterValue": "KeepEnd",
                            "Parameters": {}
                        },
                        {
                            "Display": "Keep the start of the serial number",
                            "ParameterValue": "KeepStart",
                            "Parameters": {}
                        }
                    ]
                }
            },
            "GroupTagFilter": {
                "DisplayName": "Group tag filter"
            },
            "GroupTagExcludeFilter": {
                "DisplayName": "Exclude group tags"
            },
            "RenameEnrolledDevices": {
                "DisplayName": "Rename enrolled devices?"
            },
            "MaxChangesPerRun": {
                "DisplayName": "Maximum changes per run"
            },
            "WhatIfMode": {
                "DisplayName": "Dry run?"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $false)]
    [string]$NameTemplate = "%GROUPTAG%-%SERIAL%",

    [Parameter(Mandatory = $false)]
    [ValidateSet("KeepEnd", "KeepStart")]
    [string]$SerialTruncation = "KeepEnd",

    [Parameter(Mandatory = $false)]
    [string]$GroupTagFilter = "",

    [Parameter(Mandatory = $false)]
    [string]$GroupTagExcludeFilter = "",

    [Parameter(Mandatory = $false)]
    [bool]$RenameEnrolledDevices = $true,

    [Parameter(Mandatory = $false)]
    [int]$MaxChangesPerRun = 0,

    [Parameter(Mandatory = $false)]
    [bool]$WhatIfMode = $true,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Paged Graph request failed at '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)
    return $allResults
}

# Comma-separated filter string -> trimmed, non-empty array. An empty string means "no filter".
function ConvertTo-FilterList {
    param([string]$RawValue)
    if ([string]::IsNullOrWhiteSpace($RawValue)) { return @() }
    return @($RawValue -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

# Is this a usable Graph id (not empty, not the all-zero GUID that Autopilot uses for "not enrolled")?
function Test-ValidGraphId {
    param([string]$Id)
    return (-not [string]::IsNullOrWhiteSpace($Id)) -and ($Id -ne "00000000-0000-0000-0000-000000000000")
}

# Group tag filter: exact match (case-insensitive) unless the pattern contains a '*' wildcard.
function Test-GroupTagMatch {
    param(
        [string]$Tag,
        [string[]]$Patterns
    )
    if ($null -eq $Patterns -or $Patterns.Count -eq 0) { return $true }
    foreach ($pattern in $Patterns) {
        if ($pattern.Contains('*')) {
            if ($Tag -like $pattern) { return $true }
        }
        elseif ($Tag -eq $pattern) {
            return $true
        }
    }
    return $false
}

# Removes everything that is not allowed in a Windows computer name (letters, digits, hyphen), collapses
# repeated hyphens and drops hyphens at both ends. Serial numbers and group tags may contain spaces,
# underscores, dots or slashes; virtual machine serial numbers are often hyphen-separated groups.
function Get-SanitizedNamePart {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $clean = $Value.Trim() -replace '[^A-Za-z0-9-]', ''
    $clean = $clean -replace '-{2,}', '-'
    return $clean.Trim('-')
}

# Windows computer name rules (same as the Rename Device runbook): 1-15 characters, letters, digits
# and hyphens, starting and ending with a letter or digit, not digits only.
function Test-ComputerName {
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $false }
    if ($Name -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$') { return $false }
    if ($Name -match '^\d+$') { return $false }
    return $true
}

# Validates the template once at startup. Throws with a message that names the exact problem.
function Test-NameTemplate {
    param([string]$Template)
    if ([string]::IsNullOrWhiteSpace($Template)) {
        throw "NameTemplate must not be empty. Example: %GROUPTAG%-%SERIAL%"
    }
    $serialCount = [regex]::Matches($Template, '%SERIAL%', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
    $tagCount = [regex]::Matches($Template, '%(GROUPTAG|ORDERID)%', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
    if ($serialCount -ne 1) {
        throw "NameTemplate '$Template' must contain %SERIAL% exactly once. Without the serial number every device of a location would get the same name."
    }
    if ($tagCount -ne 1) {
        throw "NameTemplate '$Template' must contain %GROUPTAG% (or %ORDERID%) exactly once."
    }
    $literal = $Template -ireplace '%(SERIAL|GROUPTAG|ORDERID)%', ''
    if ($literal.Contains('%')) {
        throw "NameTemplate '$Template' contains an unknown placeholder. Supported placeholders are %GROUPTAG% (or %ORDERID%) and %SERIAL%."
    }
    if ($literal -notmatch '^[A-Za-z0-9-]*$') {
        throw "NameTemplate '$Template' contains characters that are not allowed in a computer name. Use letters, digits and hyphens only."
    }
    if ($literal.Length -ge 15) {
        throw "NameTemplate '$Template' leaves no room for group tag and serial number. The fixed text must be shorter than 15 characters."
    }
}

# Builds the expected name for one Autopilot record. Only the serial number is shortened when the
# name would exceed 15 characters; template text and group tag are never cut.
function Get-DeviceNameFromTemplate {
    param(
        [string]$Template,
        [string]$GroupTag,
        [string]$SerialNumber,
        [string]$SerialTruncation
    )
    $result = [PSCustomObject]@{
        Name            = ""
        IsValid         = $false
        Reason          = ""
        SerialTruncated = $false
    }

    $tag = Get-SanitizedNamePart -Value $GroupTag
    if ($tag -eq "") {
        $result.Reason = "GroupTagUnusable"
        return $result
    }
    $serial = Get-SanitizedNamePart -Value $SerialNumber
    if ($serial -eq "") {
        $result.Reason = "SerialUnusable"
        return $result
    }

    $withTag = $Template -ireplace '%(GROUPTAG|ORDERID)%', $tag
    $fixedPart = $withTag -ireplace '%SERIAL%', ''
    $room = 15 - $fixedPart.Length
    if ($room -le 0) {
        $result.Reason = "NameTooLong"
        return $result
    }

    if ($serial.Length -gt $room) {
        if ($SerialTruncation -eq "KeepStart") {
            $serial = $serial.Substring(0, $room)
        }
        else {
            $serial = $serial.Substring($serial.Length - $room)
        }
        $result.SerialTruncated = $true
        # The cut can land on a hyphen; a fragment that starts or ends with one would produce "--" or a
        # trailing hyphen next to the template text. The fragment is not refilled, it may stay shorter.
        $serial = $serial.Trim('-')
        if ($serial -eq "") {
            $result.Reason = "SerialUnusable"
            return $result
        }
    }

    $name = $withTag -ireplace '%SERIAL%', $serial
    $result.Name = $name
    if (-not (Test-ComputerName -Name $name)) {
        $result.Reason = "NameInvalid"
        return $result
    }
    $result.IsValid = $true
    return $result
}

# Classifies a processed device for the Output Data tables: Changed (at least one write, planned,
# done or failed), AlreadyNamed (nothing to do on either side) or Skipped (no write, at least one reason).
function Get-DeviceOutcome {
    param(
        [Parameter(Mandatory = $true)]
        $Entry
    )
    if ($Entry.IntuneAction -in @('RenameQueued', 'WouldRenameQueue', 'RenameFailed') -or $Entry.AutopilotAction -in @('Updated', 'WouldUpdate', 'UpdateFailed')) {
        return "Changed"
    }
    if ($Entry.IsValid -and $Entry.IntuneAction -in @('AlreadyNamed', 'NotEnrolled') -and $Entry.AutopilotAction -eq 'AlreadyNamed') {
        return "AlreadyNamed"
    }
    return "Skipped"
}

# POST with a small retry for Graph throttling (429). Any other error is rethrown to the caller.
function Invoke-GraphWriteRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [hashtable]$Body
    )
    $maxAttempts = 3
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            Invoke-MgGraphRequest -Uri $Uri -Method POST -Body ($Body | ConvertTo-Json -Compress) -ContentType "application/json" -ErrorAction Stop | Out-Null
            return
        }
        catch {
            $message = $_.Exception.Message
            $isThrottled = ($message -like "*429*") -or ($message -like "*TooManyRequests*") -or ($message -like "*Too Many Requests*")
            if ($isThrottled -and $attempt -lt $maxAttempts) {
                Write-RjRbLog -Message "Graph throttled the request to '$Uri' (attempt $attempt of $maxAttempts). Waiting 10 seconds before retrying." -Verbose
                Start-Sleep -Seconds 10
                continue
            }
            throw
        }
    }
}

#endregion

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "NameTemplate: $NameTemplate" -Verbose
Write-RjRbLog -Message "SerialTruncation: $SerialTruncation" -Verbose
Write-RjRbLog -Message "GroupTagFilter: $GroupTagFilter" -Verbose
Write-RjRbLog -Message "GroupTagExcludeFilter: $GroupTagExcludeFilter" -Verbose
Write-RjRbLog -Message "RenameEnrolledDevices: $RenameEnrolledDevices" -Verbose
Write-RjRbLog -Message "MaxChangesPerRun: $MaxChangesPerRun" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

$NameTemplate = ($NameTemplate ?? "").Trim()
try {
    Test-NameTemplate -Template $NameTemplate
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    throw "Invalid parameter: NameTemplate"
}

if ($MaxChangesPerRun -lt 0) {
    Write-Error "MaxChangesPerRun ($MaxChangesPerRun) must be 0 (no limit) or a positive number." -ErrorAction Continue
    throw "Invalid parameter: MaxChangesPerRun must not be negative"
}

$groupTagPatterns = @(ConvertTo-FilterList -RawValue $GroupTagFilter)
$groupTagExcludePatterns = @(ConvertTo-FilterList -RawValue $GroupTagExcludeFilter)

if ($WhatIfMode) {
    Write-Output "Mode: dry run - nothing is written, changes are only reported"
}
else {
    Write-Output "Mode: live - names are written to Intune and Autopilot"
}
Write-Output "Name template: '$NameTemplate'"
if ($SerialTruncation -eq "KeepStart") {
    Write-Output "Serial truncation: keep the start of the serial number"
}
else {
    Write-Output "Serial truncation: keep the end of the serial number"
}
if ($groupTagPatterns.Count -gt 0) {
    Write-Output "Group tag filter: $($groupTagPatterns -join ', ')"
}
else {
    Write-Output "Group tag filter: none (all devices with a group tag)"
}
if ($groupTagExcludePatterns.Count -gt 0) {
    Write-Output "Excluded group tags: $($groupTagExcludePatterns -join ', ')"
}
else {
    Write-Output "Excluded group tags: none"
}
Write-Output "Rename enrolled devices: $RenameEnrolledDevices"
if ($MaxChangesPerRun -gt 0) {
    Write-Output "Maximum changes per run: $MaxChangesPerRun"
}
else {
    Write-Output "Maximum changes per run: no limit"
}
Write-Output "Parameter validation passed."

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connect Part"
Write-Output "---------------------"

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-RjRbLog -Message "Connected to Microsoft Graph via managed identity." -Verbose
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure that 'Connect-MgGraph -Identity' is supported in this Azure Automation account and that the system-assigned managed identity is enabled. Required Graph application permissions: DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementManagedDevices.PrivilegedOperations.All and DeviceManagementServiceConfig.ReadWrite.All. Error: $_" -ErrorAction Continue
    throw $_
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# Retrieve all Windows Autopilot device identities. The collection query already returns groupTag,
# serialNumber, displayName, azureAdDeviceId and managedDeviceId, so no per-device lookups are needed.
Write-Output "Retrieving Windows Autopilot device identities..."
$autopilotDevices = @()
try {
    $autopilotDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities")
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error "Access denied while retrieving Windows Autopilot device identities. The managed identity is missing the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments (Microsoft Graph, app ID 00000003-0000-0000-c000-000000000000). Changes may take a few minutes to propagate." -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementServiceConfig.ReadWrite.All on managed identity"
    }
    Write-Error "Failed to retrieve Windows Autopilot device identities from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($autopilotDevices.Count) Autopilot device identities." -Verbose
Write-Output "Found $($autopilotDevices.Count) Autopilot device identities."

# Retrieve all Intune managed Windows devices. The beta endpoint is required for joinType: hybrid
# joined and Entra registered devices cannot be renamed through the Intune rename action.
Write-Output "Retrieving Intune managed Windows devices..."
$intuneDevices = @()
try {
    $intuneDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,managedDeviceOwnerType,azureADDeviceId,joinType,enrolledDateTime")
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error "Access denied while retrieving Intune managed devices. The managed identity is missing the 'DeviceManagementManagedDevices.ReadWrite.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments. Changes may take a few minutes to propagate." -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementManagedDevices.ReadWrite.All on managed identity"
    }
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($intuneDevices.Count) Intune managed Windows devices." -Verbose
Write-Output "Found $($intuneDevices.Count) Intune managed Windows devices."

# In-memory lookups: by Entra device id (newest enrollment wins when a stale record shares the id),
# by Intune id (for the managedDeviceId fallback) and all names in use (to avoid creating duplicates).
$intuneByAadId = @{}
$intuneById = @{}
$namesInUse = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new([System.StringComparer]::OrdinalIgnoreCase)
$joinTypeMissingCount = 0
foreach ($device in $intuneDevices) {
    $intuneById[[string]$device.id] = $device
    $aadId = [string]$device.azureADDeviceId
    if (Test-ValidGraphId -Id $aadId) {
        $existing = $intuneByAadId[$aadId]
        if ($null -eq $existing -or ($device.enrolledDateTime -gt $existing.enrolledDateTime)) {
            $intuneByAadId[$aadId] = $device
        }
    }
    $currentName = [string]$device.deviceName
    if (-not [string]::IsNullOrWhiteSpace($currentName)) {
        if (-not $namesInUse.ContainsKey($currentName)) {
            $namesInUse[$currentName] = [System.Collections.Generic.List[string]]::new()
        }
        $namesInUse[$currentName].Add([string]$device.id)
    }
    if ([string]::IsNullOrWhiteSpace([string]$device.joinType) -or ([string]$device.joinType) -eq 'unknown') {
        $joinTypeMissingCount++
    }
}
if ($joinTypeMissingCount -gt 0) {
    Write-RjRbLog -Message "Join type not returned for $joinTypeMissingCount of $($intuneDevices.Count) Intune devices. These devices are treated as Entra joined." -Verbose
    Write-Output "INFO: Join type not returned for $joinTypeMissingCount device(s); they are treated as Entra joined."
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Main Part"
Write-Output "---------------------"

# --- Scope: Autopilot devices with a group tag that matches the filter, in a deterministic order ---
$noGroupTagCount = 0
$filteredOutCount = 0
$excludedByListCount = 0
$inScope = [System.Collections.Generic.List[object]]::new()
foreach ($ap in $autopilotDevices) {
    $tag = ([string]$ap.groupTag).Trim()
    if ($tag -eq "") {
        $noGroupTagCount++
        continue
    }
    if (-not (Test-GroupTagMatch -Tag $tag -Patterns $groupTagPatterns)) {
        $filteredOutCount++
        continue
    }
    if ($groupTagExcludePatterns.Count -gt 0 -and (Test-GroupTagMatch -Tag $tag -Patterns $groupTagExcludePatterns)) {
        $excludedByListCount++
        continue
    }
    $inScope.Add($ap)
}
$inScope = @($inScope | Sort-Object -Property @{ Expression = { [string]$_.groupTag } }, @{ Expression = { [string]$_.serialNumber } })

Write-Output "Autopilot devices without group tag (ignored): $noGroupTagCount"
if ($groupTagPatterns.Count -gt 0) {
    Write-Output "Autopilot devices excluded by group tag filter: $filteredOutCount"
}
if ($groupTagExcludePatterns.Count -gt 0) {
    Write-Output "Autopilot devices excluded by the exclude list: $excludedByListCount"
}
Write-Output "Autopilot devices in scope: $($inScope.Count)"
Write-RjRbLog -Message "Scope: $($inScope.Count) in scope, $noGroupTagCount without group tag, $filteredOutCount excluded by filter, $excludedByListCount excluded by the exclude list." -Verbose

# --- Build the expected name for every device in scope ---
$results = [System.Collections.Generic.List[object]]::new()
foreach ($ap in $inScope) {
    $nameResult = Get-DeviceNameFromTemplate -Template $NameTemplate -GroupTag ([string]$ap.groupTag) -SerialNumber ([string]$ap.serialNumber) -SerialTruncation $SerialTruncation

    $aadId = ""
    if (Test-ValidGraphId -Id ([string]$ap.azureAdDeviceId)) {
        $aadId = [string]$ap.azureAdDeviceId
    }
    elseif (Test-ValidGraphId -Id ([string]$ap.azureActiveDirectoryDeviceId)) {
        $aadId = [string]$ap.azureActiveDirectoryDeviceId
    }
    $managedDeviceId = ""
    if (Test-ValidGraphId -Id ([string]$ap.managedDeviceId)) {
        $managedDeviceId = [string]$ap.managedDeviceId
    }

    $results.Add([PSCustomObject]@{
            SerialNumber    = [string]$ap.serialNumber
            GroupTag        = ([string]$ap.groupTag).Trim()
            ExpectedName    = $nameResult.Name
            IntuneName      = ""
            AutopilotName   = [string]$ap.displayName
            IntuneAction    = ""
            AutopilotAction = ""
            Reason          = $nameResult.Reason
            AutopilotId     = [string]$ap.id
            AadDeviceId     = $aadId
            ManagedDeviceId = $managedDeviceId
            IsValid         = $nameResult.IsValid
            SerialTruncated = $nameResult.SerialTruncated
        })
}

# --- Collision check: two records that would end up with the same name are both skipped ---
$collisionGroups = @($results | Where-Object { $_.IsValid } | Group-Object -Property ExpectedName | Where-Object { $_.Count -gt 1 })
foreach ($group in $collisionGroups) {
    $serials = @($group.Group | ForEach-Object { $_.SerialNumber }) -join ', '
    foreach ($entry in $group.Group) {
        $entry.IsValid = $false
        $entry.Reason = "NameCollision"
    }
    Write-Output "WARNING: $($group.Count) Autopilot devices would get the same name '$($group.Name)' (serial numbers: $serials). These devices are skipped."
    Write-RjRbLog -Message "Name collision on '$($group.Name)' for serial numbers $serials. Devices skipped." -Verbose
}

# --- Apply: compare with Intune and Autopilot, queue the rename and update the Autopilot record ---
Write-Output ""
if ($WhatIfMode) {
    Write-Output "Comparing names (dry run, nothing is written)..."
}
else {
    Write-Output "Comparing names and applying changes..."
}
Write-Output "---------------------"

$changedDeviceCount = 0
$noChangeCount = 0
$notEnrolledCount = 0
$renameQueuedCount = 0
$renamePendingCount = 0
$autopilotUpdatedCount = 0
$renameDisabledCount = 0
$notCompanyOwnedCount = 0
$notEntraJoinedCount = 0
$nameInUseCount = 0
$invalidNameCount = 0
$limitReachedCount = 0
$failedCount = 0

foreach ($entry in $results) {
    if (-not $entry.IsValid) {
        $invalidNameCount++
        $nameHint = ""
        if ($entry.ExpectedName -ne "") { $nameHint = " ('$($entry.ExpectedName)')" }
        Write-Output "SKIP serial '$($entry.SerialNumber)', group tag '$($entry.GroupTag)': $($entry.Reason)$nameHint"
        continue
    }

    $expected = $entry.ExpectedName

    # Resolve the Intune record: by Entra device id first, by the Autopilot managedDeviceId as fallback
    # (hybrid deployments point the Autopilot record at the pre-created Entra object).
    $intuneDevice = $null
    if ($entry.AadDeviceId -ne "" -and $intuneByAadId.ContainsKey($entry.AadDeviceId)) {
        $intuneDevice = $intuneByAadId[$entry.AadDeviceId]
    }
    elseif ($entry.ManagedDeviceId -ne "" -and $intuneById.ContainsKey($entry.ManagedDeviceId)) {
        $intuneDevice = $intuneById[$entry.ManagedDeviceId]
    }

    # Intune decision (string comparisons are case-insensitive)
    if ($null -eq $intuneDevice) {
        $entry.IntuneAction = "NotEnrolled"
        $notEnrolledCount++
    }
    else {
        $entry.IntuneName = [string]$intuneDevice.deviceName
        $joinType = [string]$intuneDevice.joinType
        $otherDevicesWithName = 0
        if ($namesInUse.ContainsKey($expected)) {
            $otherDevicesWithName = @($namesInUse[$expected] | Where-Object { $_ -ne [string]$intuneDevice.id }).Count
        }

        if ($entry.IntuneName -eq $expected) {
            $entry.IntuneAction = "AlreadyNamed"
        }
        elseif (-not $RenameEnrolledDevices) {
            $entry.IntuneAction = "RenameDisabled"
            $renameDisabledCount++
        }
        elseif (([string]$intuneDevice.managedDeviceOwnerType) -ne 'company') {
            $entry.IntuneAction = "NotCompanyOwned"
            $notCompanyOwnedCount++
        }
        elseif ($joinType -in @('hybridAzureADJoined', 'azureADRegistered')) {
            $entry.IntuneAction = "NotEntraJoined"
            $notEntraJoinedCount++
        }
        elseif ($otherDevicesWithName -gt 0) {
            $entry.IntuneAction = "NameInUseByOtherDevice"
            $nameInUseCount++
        }
        else {
            $entry.IntuneAction = "Rename"
        }
    }

    # Autopilot decision: the record always converges to the expected name, also for devices that are
    # not enrolled yet (the name is applied at the next Autopilot deployment).
    if ($entry.AutopilotName -eq $expected) {
        $entry.AutopilotAction = "AlreadyNamed"
    }
    else {
        $entry.AutopilotAction = "Update"
    }

    $wantsWrite = ($entry.IntuneAction -eq "Rename") -or ($entry.AutopilotAction -eq "Update")
    if (-not $wantsWrite) {
        $noChangeCount++
        continue
    }

    if ($MaxChangesPerRun -gt 0 -and $changedDeviceCount -ge $MaxChangesPerRun) {
        if ($entry.IntuneAction -eq "Rename") { $entry.IntuneAction = "MaxChangesReached" }
        if ($entry.AutopilotAction -eq "Update") { $entry.AutopilotAction = "MaxChangesReached" }
        $entry.Reason = "MaxChangesReached"
        $limitReachedCount++
        continue
    }

    $deviceChanged = $false

    if ($entry.IntuneAction -eq "Rename") {
        # Do not queue a second rename while one is still pending or active from an earlier run.
        $pendingRename = $null
        try {
            $actionCheck = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($intuneDevice.id)?`$select=deviceActionResults" -Method GET -ErrorAction Stop
            $pendingRename = @($actionCheck.deviceActionResults | Where-Object { $_.actionName -eq 'setDeviceName' -and $_.actionState -in @('pending', 'active') }) | Select-Object -First 1
        }
        catch {
            Write-RjRbLog -Message "WARNING: Could not check pending actions for '$($entry.IntuneName)' (Intune id: $($intuneDevice.id)). Proceeding with the rename. Error: $($_.Exception.Message)" -Verbose
        }

        if ($pendingRename) {
            $entry.IntuneAction = "RenamePending"
            $renamePendingCount++
            Write-Output "INFO: Intune rename of '$($entry.IntuneName)' to '$expected' is already $($pendingRename.actionState) (queued: $($pendingRename.startDateTime)). Not queued again."
        }
        elseif ($WhatIfMode) {
            $entry.IntuneAction = "WouldRenameQueue"
            $renameQueuedCount++
            $deviceChanged = $true
            Write-Output "DRY RUN: would queue Intune rename '$($entry.IntuneName)' -> '$expected' (serial '$($entry.SerialNumber)')"
        }
        else {
            try {
                Invoke-GraphWriteRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($intuneDevice.id)/setDeviceName" -Body @{ deviceName = $expected }
                $entry.IntuneAction = "RenameQueued"
                $renameQueuedCount++
                $deviceChanged = $true
                Write-Output "Intune rename queued: '$($entry.IntuneName)' -> '$expected' (serial '$($entry.SerialNumber)'; applied at next check-in and restart)"
                Write-RjRbLog -Message "Intune rename queued for '$($entry.IntuneName)' (Intune id: $($intuneDevice.id)) -> '$expected'." -Verbose
            }
            catch {
                $entry.IntuneAction = "RenameFailed"
                $failedCount++
                Write-Output "ERROR: Intune rename of '$($entry.IntuneName)' to '$expected' failed: $($_.Exception.Message)"
                Write-RjRbLog -Message "WARNING: Failed to queue the Intune rename of '$($entry.IntuneName)' (Intune id: $($intuneDevice.id)) to '$expected' via POST beta/deviceManagement/managedDevices/.../setDeviceName. If the error is 403 Forbidden, the managed identity requires the 'DeviceManagementManagedDevices.PrivilegedOperations.All' application permission in Entra ID. Error: $($_.Exception.Message)" -NoDebugOnly
            }
            Start-Sleep -Milliseconds 200
        }
    }

    if ($entry.AutopilotAction -eq "Update") {
        if ($WhatIfMode) {
            $entry.AutopilotAction = "WouldUpdate"
            $autopilotUpdatedCount++
            $deviceChanged = $true
            Write-Output "DRY RUN: would set Autopilot name '$($entry.AutopilotName)' -> '$expected' (serial '$($entry.SerialNumber)')"
        }
        else {
            try {
                Invoke-GraphWriteRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($entry.AutopilotId)/updateDeviceProperties" -Body @{ displayName = $expected }
                $entry.AutopilotAction = "Updated"
                $autopilotUpdatedCount++
                $deviceChanged = $true
                Write-Output "Autopilot name updated: '$($entry.AutopilotName)' -> '$expected' (serial '$($entry.SerialNumber)')"
                Write-RjRbLog -Message "Autopilot display name updated for serial '$($entry.SerialNumber)' (Autopilot id: $($entry.AutopilotId)) -> '$expected'." -Verbose
            }
            catch {
                $entry.AutopilotAction = "UpdateFailed"
                $failedCount++
                Write-Output "ERROR: Autopilot name update for serial '$($entry.SerialNumber)' to '$expected' failed: $($_.Exception.Message)"
                Write-RjRbLog -Message "WARNING: Failed to update the Autopilot display name for serial '$($entry.SerialNumber)' (Autopilot id: $($entry.AutopilotId)) via POST beta/deviceManagement/windowsAutopilotDeviceIdentities/.../updateDeviceProperties. If the error is 403 Forbidden, the managed identity requires the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Entra ID. Error: $($_.Exception.Message)" -NoDebugOnly
            }
            Start-Sleep -Milliseconds 200
        }
    }

    if ($deviceChanged) {
        $changedDeviceCount++
    }
}

if ($limitReachedCount -gt 0) {
    Write-Output ""
    Write-Output "INFO: The limit of $MaxChangesPerRun changed devices was reached. $limitReachedCount further device(s) are processed in a later run."
}

# --- Summary ---
Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Autopilot devices total: $($autopilotDevices.Count)"
Write-Output "Autopilot devices in scope: $($results.Count)"
Write-Output "Devices with nothing to write: $noChangeCount"
Write-Output "Devices not enrolled in Intune (Autopilot record only): $notEnrolledCount"
if ($WhatIfMode) {
    Write-Output "Intune renames that would be queued: $renameQueuedCount"
    Write-Output "Autopilot names that would be updated: $autopilotUpdatedCount"
}
else {
    Write-Output "Intune renames queued: $renameQueuedCount"
    Write-Output "Autopilot names updated: $autopilotUpdatedCount"
}
Write-Output "Intune renames already pending from an earlier run: $renamePendingCount"
Write-Output "Skipped Intune rename, renaming enrolled devices is off: $renameDisabledCount"
Write-Output "Skipped Intune rename, not corporate-owned: $notCompanyOwnedCount"
Write-Output "Skipped Intune rename, hybrid joined or Entra registered: $notEntraJoinedCount"
Write-Output "Skipped Intune rename, name in use by another device: $nameInUseCount"
Write-Output "Skipped, no valid name (unusable values, too long, invalid, collision): $invalidNameCount"
Write-Output "Not processed, change limit reached: $limitReachedCount"
Write-Output "Failed writes: $failedCount"
Write-RjRbLog -Message "Run complete. Changed devices: $changedDeviceCount, renames queued: $renameQueuedCount, Autopilot updated: $autopilotUpdatedCount, failed: $failedCount, dry run: $WhatIfMode." -Verbose

if ($failedCount -gt 0) {
    Write-Error "$failedCount write(s) to Intune or Autopilot failed. See the device table and the job log for details." -ErrorAction Continue
}

#endregion

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last on purpose so the tables are not interleaved with the progress output. Every table gets its
# own RjTableTitle marker and its own column set. A marker is only written when rows follow it, because
# the portal applies the name to the next table it receives.
Write-Output ""

# Table 1: summary counters
$summaryValues = [ordered]@{
    "Autopilot devices total"                                  = $autopilotDevices.Count
    "Without group tag (ignored)"                              = $noGroupTagCount
    "Excluded by group tag filter"                             = $filteredOutCount
    "Excluded by the exclude list"                             = $excludedByListCount
    "In scope"                                                 = $results.Count
    "Devices with nothing to write"                            = $noChangeCount
    "Devices not enrolled in Intune (Autopilot record only)"   = $notEnrolledCount
    "Intune renames already pending from an earlier run"       = $renamePendingCount
    "Skipped Intune rename, renaming enrolled devices is off"  = $renameDisabledCount
    "Skipped Intune rename, not corporate-owned"               = $notCompanyOwnedCount
    "Skipped Intune rename, hybrid joined or Entra registered" = $notEntraJoinedCount
    "Skipped Intune rename, name in use by another device"     = $nameInUseCount
    "Skipped, no valid name"                                   = $invalidNameCount
    "Not processed, change limit reached"                      = $limitReachedCount
    "Failed writes"                                            = $failedCount
}
if ($WhatIfMode) {
    $summaryValues["Devices that would change"] = $changedDeviceCount
    $summaryValues["Intune renames that would be queued"] = $renameQueuedCount
    $summaryValues["Autopilot names that would be updated"] = $autopilotUpdatedCount
}
else {
    $summaryValues["Devices changed"] = $changedDeviceCount
    $summaryValues["Intune renames queued"] = $renameQueuedCount
    $summaryValues["Autopilot names updated"] = $autopilotUpdatedCount
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

# Tables 2-4: devices by outcome
$changedRows = [System.Collections.Generic.List[object]]::new()
$skippedRows = [System.Collections.Generic.List[object]]::new()
$alreadyNamedRows = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $results) {
    switch (Get-DeviceOutcome -Entry $entry) {
        "Changed" {
            $changedRows.Add([PSCustomObject]@{
                    SerialNumber    = $entry.SerialNumber
                    GroupTag        = $entry.GroupTag
                    IntuneName      = $entry.IntuneName
                    AutopilotName   = $entry.AutopilotName
                    NewName         = $entry.ExpectedName
                    IntuneAction    = $entry.IntuneAction
                    AutopilotAction = $entry.AutopilotAction
                })
        }
        "AlreadyNamed" {
            $enrolled = "Yes"
            if ($entry.IntuneAction -eq "NotEnrolled") { $enrolled = "No" }
            $alreadyNamedRows.Add([PSCustomObject]@{
                    SerialNumber = $entry.SerialNumber
                    GroupTag     = $entry.GroupTag
                    DeviceName   = $entry.ExpectedName
                    Enrolled     = $enrolled
                })
        }
        default {
            # Reason carries the name problem or the change limit; otherwise the Intune action that blocked the rename.
            $reason = $entry.Reason
            if ($reason -eq "") { $reason = $entry.IntuneAction }
            $skippedRows.Add([PSCustomObject]@{
                    SerialNumber    = $entry.SerialNumber
                    GroupTag        = $entry.GroupTag
                    ExpectedName    = $entry.ExpectedName
                    IntuneName      = $entry.IntuneName
                    AutopilotName   = $entry.AutopilotName
                    IntuneAction    = $entry.IntuneAction
                    AutopilotAction = $entry.AutopilotAction
                    Reason          = $reason
                })
        }
    }
}

if ($results.Count -eq 0) {
    Write-Output "No Autopilot devices in scope."
}

$changesTitle = "Applied changes"
if ($WhatIfMode) { $changesTitle = "Planned changes (dry run)" }
if ($changedRows.Count -gt 0) {
    Write-Output "$($changedRows.Count) device(s) with changes:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = $changesTitle })
    Write-Output $changedRows.ToArray()
}
elseif ($results.Count -gt 0) {
    Write-Output "No device changes."
}

if ($skippedRows.Count -gt 0) {
    Write-Output "$($skippedRows.Count) skipped device(s):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Skipped devices" })
    Write-Output $skippedRows.ToArray()
}
elseif ($results.Count -gt 0) {
    Write-Output "No skipped devices."
}

if ($alreadyNamedRows.Count -gt 0) {
    Write-Output "$($alreadyNamedRows.Count) device(s) already named:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Devices already named" })
    Write-Output $alreadyNamedRows.ToArray()
}
elseif ($results.Count -gt 0) {
    Write-Output "No devices already named."
}

#endregion

########################################################
#region     Cleanup
########################################################

Write-Output ""
Write-Output "Cleanup"
Write-Output "---------------------"

try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-RjRbLog -Message "Disconnected from Microsoft Graph." -Verbose
}
catch {
    Write-Warning "Could not cleanly disconnect from Microsoft Graph: $_"
}

Write-Output ""
Write-Output "Done!"

#endregion
