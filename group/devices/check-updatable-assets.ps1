<#
	.SYNOPSIS
	Check Windows Update for Business enrollment of this group's devices

	.DESCRIPTION
	Checks every device in this group for registration as an updatable asset in Windows Update for Business. The result is written to Output Data as a summary line, then one table with a row per device. Each row shows the enrollment state for the feature, quality and driver update categories and any error Windows Update returns. Nothing is changed on the devices or in the group.

	.PARAMETER GroupId
	Object ID of the group the runbook acts on. Set by the portal from the selected group.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "CallerName": {
	            "Hide": true
	        },
	        "GroupId": {
	            "Hide": true
	        }
	    }
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }

param(
    [Parameter(Mandatory = $true)]
    [string]$GroupId,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "GroupId: $GroupId" -Verbose
#endregion RJ Log Part

########################################################
#region     Function Definitions
########################################################
function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}
#endregion Function Definitions

########################################################
#region     Connect Part
########################################################
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    # Connection failure: managed identity missing/disabled or Graph unreachable
    Write-Error "Microsoft Graph connection could not be established with the managed identity. Verify that the system-assigned managed identity of the Automation account is enabled. Details: $($_.Exception.Message)" -ErrorAction Continue
    throw "Connection to Microsoft Graph failed"
}

Write-Output "Validating Graph permissions..."
try {
    $mgContext = Get-MgContext -ErrorAction Stop
    $grantedScopes = $mgContext.Scopes

    # Required Graph app permissions for this runbook (from .permissions.json)
    $requiredPermissions = @(
        "Device.Read.All",
        "Group.Read.All",
        "WindowsUpdates.ReadWrite.All"
    )

    # Subsumption: a broader permission implicitly covers a narrower one.
    $subsumptionMap = @{
        "Group.Read.All"  = @("Group.ReadWrite.All", "Directory.ReadWrite.All")
        "Device.Read.All" = @("Device.ReadWrite.All", "Directory.ReadWrite.All")
    }

    $missingPermissions = @()
    foreach ($required in $requiredPermissions) {
        $covered = $grantedScopes -contains $required
        if (-not $covered -and $subsumptionMap.ContainsKey($required)) {
            foreach ($broader in $subsumptionMap[$required]) {
                if ($grantedScopes -contains $broader) {
                    $covered = $true
                    break
                }
            }
        }
        if (-not $covered) {
            $missingPermissions += $required
        }
    }

    if ($missingPermissions.Count -gt 0) {
        Write-Error "Missing required Microsoft Graph permissions: $($missingPermissions -join ', '). Ensure the managed identity has the necessary app role assignments." -ErrorAction Continue
        throw "Insufficient Graph permissions"
    }
    Write-Output "Graph permissions validated."
}
catch {
    # The missing-permissions case was already reported above; do not log it twice
    if ($_.Exception.Message -ne "Insufficient Graph permissions") {
        Write-Error "Graph permissions could not be validated: $($_.Exception.Message). Verify the managed identity is connected and has Group.Read.All, Device.Read.All and WindowsUpdates.ReadWrite.All." -ErrorAction Continue
    }
    throw
}
#endregion Connect Part

########################################################
#region     Data Collection
########################################################
# Resolve the group display name for output
try {
    $groupResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/${GroupId}?`$select=displayName" -Method GET -ErrorAction Stop
    $groupDisplayName = $groupResponse['displayName']
}
catch {
    Write-RjRbLog -Message "Group lookup failed for ID '$GroupId': $($_.Exception.Message)" -Verbose
    $message = $_.Exception.Message
    if ($message -like "*404*" -or $message -like "*NotFound*" -or $message -like "*Request_ResourceNotFound*") {
        # Group deleted or ID wrong
        Write-Error "The group with ID '$GroupId' was not found. It may have been deleted. Please verify the group still exists in Entra ID." -ErrorAction Continue
        throw "Group '$GroupId' not found"
    }
    elseif ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*Authorization_RequestDenied*") {
        Write-Error "Access denied while reading group '$GroupId'. The managed identity needs the Group.Read.All and Device.Read.All application permissions. Please contact your RealmJoin administrator to verify the runbook permissions." -ErrorAction Continue
        throw "Insufficient Microsoft Graph permissions to read group"
    }
    else {
        Write-Error "The group with ID '$GroupId' could not be resolved: $message" -ErrorAction Continue
        throw "Group '$GroupId' could not be resolved"
    }
}

Write-Output ""
Write-Output "Windows Update readiness for group '$groupDisplayName'"
Write-Output "---------------------"

# Read all device members (paged). The cast endpoint returns devices only.
Write-RjRbLog -Message "Fetching device members of group '$groupDisplayName' ($GroupId)" -Verbose
try {
    # Collect into a typed list: Get-GraphPagedResult returns a bare hashtable for a single device,
    # which would otherwise be enumerated as key/value pairs.
    $deviceMembers = [System.Collections.Generic.List[object]]::new()
    foreach ($member in (Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/microsoft.graph.device?`$select=id,deviceId,displayName")) {
        if ($null -ne $member) { $deviceMembers.Add($member) }
    }
}
catch {
    Write-RjRbLog -Message "Device member lookup failed for group '$groupDisplayName': $($_.Exception.Message)" -Verbose
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*Authorization_RequestDenied*") {
        Write-Error "Access denied while listing the device members of group '$groupDisplayName'. The managed identity needs the Group.Read.All and Device.Read.All application permissions. Please contact your RealmJoin administrator to verify the runbook permissions." -ErrorAction Continue
        throw "Insufficient Microsoft Graph permissions to list group members"
    }
    elseif ($message -like "*404*" -or $message -like "*NotFound*") {
        Write-Error "The group '$groupDisplayName' ($GroupId) was not found while listing its members. It may have been deleted during the run." -ErrorAction Continue
        throw "Group '$groupDisplayName' not found"
    }
    else {
        Write-Error "The device members of group '$groupDisplayName' could not be read: $message" -ErrorAction Continue
        throw "Device members of group '$groupDisplayName' could not be read"
    }
}

$assetResults = [System.Collections.Generic.List[object]]::new()

if ($null -eq $deviceMembers -or $deviceMembers.Count -eq 0) {
    Write-Output "No devices are members of this group. Nothing to check."
}
else {
    Write-Output "Checking $($deviceMembers.Count) devices..."

    foreach ($deviceMember in $deviceMembers) {
        $deviceId   = $deviceMember['deviceId']
        $deviceName = $deviceMember['displayName']
        $asset      = $null
        $notFound   = $false
        $errorCode  = $null

        if ([string]::IsNullOrWhiteSpace($deviceId)) {
            $errorCode = 'NoDeviceId'
        }
        else {
            try {
                $asset = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$deviceId" -Method GET -ErrorAction Stop
            }
            catch {
                $graphError = $_
                $httpStatus = $null
                $graphCode  = $null

                $statusCode = $graphError.Exception.Response.StatusCode
                if ($null -ne $statusCode) { $httpStatus = [int]$statusCode }

                if ($graphError.ErrorDetails.Message) {
                    try {
                        $errorBody = $graphError.ErrorDetails.Message | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                        if ($errorBody['error'] -is [hashtable]) {
                            $graphCode = [string]$errorBody['error']['code']
                        }
                    }
                    catch {
                        Write-RjRbLog -Message "Error body for '$deviceName' is not JSON: $($_.Exception.Message)" -Verbose
                    }
                }

                # Fallback: no HTTP status and no parsed error code, but the raw text says NotFound or 404
                if (-not $httpStatus -and -not $graphCode) {
                    $rawText = "$($graphError.Exception.Message) $($graphError.ErrorDetails.Message)"
                    if ($rawText -match 'NotFound|404') { $notFound = $true }
                }

                if ($notFound -or $httpStatus -eq 404 -or $graphCode -eq 'NotFound') {
                    # Not onboarded to Windows Update for Business updatable assets
                    $notFound = $true
                }
                elseif ($httpStatus -eq 403 -or $graphCode -in @('Forbidden', 'Authorization_RequestDenied')) {
                    # Missing WindowsUpdates.ReadWrite.All or no Windows Update for Business license; record only, never throw
                    $errorCode = 'Forbidden'
                }
                elseif ($graphCode) {
                    $errorCode = $graphCode
                }
                elseif ($httpStatus) {
                    $errorCode = "HTTP $httpStatus"
                }
                else {
                    $errorCode = $graphError.Exception.GetType().Name
                }

                Write-RjRbLog -Message "Updatable asset lookup for '$deviceName' ($deviceId) failed: $($graphError.Exception.Message) $($graphError.ErrorDetails.Message)" -Verbose
            }
        }

        $assetResults.Add([PSCustomObject]@{
            DeviceName = $deviceName
            DeviceId   = $deviceId
            Asset      = $asset
            NotFound   = $notFound
            ErrorCode  = $errorCode
        })
    }
}

Write-RjRbLog -Message "Checked $($assetResults.Count) devices for updatable asset onboarding" -Verbose

# If every device was denied, this is a permission/license problem, not a per-device one
if ($assetResults.Count -gt 0 -and @($assetResults | Where-Object { $_.ErrorCode -eq 'Forbidden' }).Count -eq $assetResults.Count) {
    Write-RjRbLog -Message "WARNING: Access was denied for all devices. Verify that the managed identity has WindowsUpdates.ReadWrite.All and that the tenant has a license that includes the Windows Update for Business deployment service (for example Windows E3/E5 or equivalent)."
}
#endregion Data Collection

########################################################
#region     Data Processing
########################################################
# Reads the enrollmentState of one update category ("feature", "quality", "driver").
# Returns "-" when the enrollment block, the category or its state is missing.
$getCategoryState = {
    param($Enrollment, $Category)
    if ($Enrollment -is [System.Collections.IDictionary] -and
        $Enrollment[$Category] -is [System.Collections.IDictionary] -and
        -not [string]::IsNullOrWhiteSpace([string]$Enrollment[$Category]['enrollmentState'])) {
        [string]$Enrollment[$Category]['enrollmentState']
    }
    else {
        "-"
    }
}

$reportRows        = [System.Collections.Generic.List[object]]::new()
$onboardedCount    = 0
$notOnboardedCount = 0
$withErrorsCount   = 0

foreach ($item in $assetResults) {
    $asset = $item.Asset

    # Device name first; fall back to the Entra device ID when the name is empty.
    $deviceLabel = if (-not [string]::IsNullOrWhiteSpace([string]$item.DeviceName)) {
        [string]$item.DeviceName
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$item.DeviceId)) {
        [string]$item.DeviceId
    }
    else {
        "-"
    }

    $feature   = "-"
    $quality   = "-"
    $driver    = "-"
    $errorText = "-"

    if ($null -ne $asset) {
        $status = "Onboarded"

        $enrollment = if ($asset -is [System.Collections.IDictionary]) { $asset['enrollment'] } else { $null }
        $feature = & $getCategoryState $enrollment 'feature'
        $quality = & $getCategoryState $enrollment 'quality'
        $driver  = & $getCategoryState $enrollment 'driver'

        $errorReasons = if ($asset -is [System.Collections.IDictionary] -and $asset['errors']) {
            (@($asset['errors']) | ForEach-Object {
                if ($_ -is [System.Collections.IDictionary] -and -not [string]::IsNullOrWhiteSpace([string]$_['reason'])) {
                    [string]$_['reason']
                }
            }) -join ", "
        }
        else {
            ""
        }
        if (-not [string]::IsNullOrWhiteSpace($errorReasons)) {
            $errorText = $errorReasons
        }
    }
    elseif ([bool]$item.NotFound) {
        $status = "Not onboarded"
    }
    else {
        $status = "Error"
        # Map raw error tokens to readable text; other Graph error codes are shown as they are.
        $errorCode = [string]$item.ErrorCode
        $errorText = if ([string]::IsNullOrWhiteSpace($errorCode)) {
            "Unknown error"
        }
        elseif ($errorCode -eq 'NoDeviceId') {
            "Device has no Entra device ID"
        }
        elseif ($errorCode -eq 'Forbidden') {
            "Access denied"
        }
        elseif ($errorCode -match '^HTTP (\d+)$') {
            "Graph error (HTTP $($Matches[1]))"
        }
        else {
            $errorCode
        }
    }

    if ($status -eq "Onboarded") {
        $onboardedCount++
        if ($errorText -ne "-") { $withErrorsCount++ }
    }
    elseif ($status -eq "Not onboarded") {
        $notOnboardedCount++
    }
    else {
        $withErrorsCount++
    }

    $reportRows.Add([PSCustomObject]@{
        Device  = $deviceLabel
        Status  = $status
        Feature = $feature
        Quality = $quality
        Driver  = $driver
        Errors  = $errorText
    })
}

$summaryStats = [PSCustomObject]@{
    Total        = $reportRows.Count
    Onboarded    = $onboardedCount
    NotOnboarded = $notOnboardedCount
    WithErrors   = $withErrorsCount
}

Write-RjRbLog -Message "Group '$groupDisplayName': processed $($summaryStats.Total) device(s), $($summaryStats.Onboarded) onboarded" -Verbose

if ($summaryStats.Total -gt 0) {
    # Onboarded devices first, then everything else; alphabetical by device within each group.
    $reportRows = $reportRows | Sort-Object -Property @{ Expression = { if ($_.Status -eq "Onboarded") { 0 } else { 1 } } }, Device

    Write-Output ""
    Write-Output "Windows Update for Business enrollment"
    Write-Output "---------------------"
    Write-Output "Summary: $($summaryStats.Total) devices - $($summaryStats.Onboarded) onboarded, $($summaryStats.NotOnboarded) not onboarded, $($summaryStats.WithErrors) with errors"

    # Output Data tab: the marker, then the rows; Select-Object picks the columns
    Write-Output ([PSCustomObject]@{ RjTableTitle = 'Update enrollment' })
    Write-Output ($reportRows | Select-Object Device, Status, Feature, Quality, Driver, Errors)
}
else {
    # No marker without rows: an empty result gets a status line instead of a table
    Write-Output "No devices to report on."
}
#endregion Data Processing

########################################################
#region     Cleanup
########################################################
try {
    Disconnect-MgGraph -ErrorAction Stop | Out-Null
}
catch {
    Write-RjRbLog -Message "Disconnect-MgGraph failed (ignored): $($_.Exception.Message)" -Verbose
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup
