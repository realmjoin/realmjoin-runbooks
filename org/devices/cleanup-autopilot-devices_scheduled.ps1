<#
	.SYNOPSIS
	Clean up orphaned and stale Windows Autopilot device registrations

	.DESCRIPTION
	This scheduled runbook performs regular maintenance of Windows Autopilot device registrations by identifying and removing orphaned devices whose serial numbers no longer match any Intune managed device, and optionally removing never-enrolled Autopilot devices that exceed a configurable age threshold. The runbook operates in WhatIf mode by default for safe reporting, and can optionally send an email summary with a CSV attachment listing the devices that would be or were deleted.

	.NOTES
	Prerequisites:
	- The Azure Automation managed identity must hold these Microsoft Graph application
	  permissions: DeviceManagementManagedDevices.Read.All,
	  DeviceManagementServiceConfig.ReadWrite.All, Organization.Read.All, Device.ReadWrite.All
	  (Device.ReadWrite.All only when the "Delete Autopilot and Entra device" mode is used), and
	  Mail.Send (Mail.Send only when email reporting is enabled).
	- Grant the permissions before the first scheduled run.

	Warning - deletion is irreversible:
	- Removing an Autopilot device identity permanently deletes it from Windows Autopilot.
	- The physical device cannot re-enter Autopilot until its hardware hash is re-uploaded.
	- There is no soft-delete or recycle bin for Autopilot records.
	- Deleting the Entra (Azure AD) device object is likewise permanent; only do so for records
	  that are genuinely dead (the device will never enroll again).

	Recommended first-run procedure:
	- Run with Delete mode = "WhatIf (report only)" (the default) and review the output or emailed CSV.
	- Confirm the identified devices are genuinely orphaned or never-enrolled.
	- Switch to a deletion mode only after the candidate list has been reviewed.

	Parameter interactions:
	- DeleteMode defaults to "WhatIf (report only)"; no deletions occur in that mode.
	- "Delete Autopilot device" removes only the Autopilot identity. "Delete Autopilot and Entra
	  device" additionally removes the matching Entra (Azure AD) device object, which would
	  otherwise be left behind as a stale/dead record once the Autopilot identity is gone.
	- CleanupOrphanedDevices and CleanupNeverEnrolledDevices are independent; either or both
	  can be enabled. NeverEnrolledAgeDays applies only to the never-enrolled check.
	- GroupTagFilter, ManufacturerFilter and ModelFilter are all optional; leave a filter empty to
	  evaluate all values for that dimension. When more than one filter is set they are combined with
	  AND - a device must match every populated filter to remain in scope. GroupTagFilter matches the
	  group tag exactly (case-insensitive); ManufacturerFilter and ModelFilter match as case-insensitive
	  substrings, so "Dell" matches "Dell Inc." and "Surface" matches "Surface Laptop 3".
	- ExcludeSerialNumbers is applied after the AND filters as an exclusion: any device whose serial
	  number is in the list (exact, case-insensitive) is removed from scope regardless of the other
	  filters. Leave empty to exclude nothing.

	.PARAMETER DeleteMode
	Controls what the runbook does with the identified cleanup candidates. "WhatIf (report only)" performs no deletion and only reports the candidates (default, safe). "Delete Autopilot device" removes the Autopilot device identities. "Delete Autopilot and Entra device" removes the Autopilot identities and the matching Entra (Azure AD) device objects, which would otherwise remain as stale records.

	.PARAMETER GroupTagFilter
	Comma-separated Autopilot group tags to limit the cleanup scope. Matched exactly (case-insensitive). Leave empty to process all Autopilot devices regardless of group tag.

	.PARAMETER ManufacturerFilter
	Comma-separated device manufacturers to limit the cleanup scope. Matched as case-insensitive substrings, so "Dell" matches "Dell Inc.". Combined with the other filters using AND. Leave empty to process all manufacturers.

	.PARAMETER ModelFilter
	Comma-separated device models to limit the cleanup scope. Matched as case-insensitive substrings, so "Surface" matches "Surface Laptop 3". Combined with the other filters using AND. Leave empty to process all models.

	.PARAMETER ExcludeSerialNumbers
	Comma-separated serial numbers to exclude from the cleanup. Matched exactly (case-insensitive). Any device whose serial number is in this list is removed from scope regardless of the other filters. Leave empty to exclude nothing.

	.PARAMETER CleanupOrphanedDevices
	When enabled, removes Autopilot devices that have contacted Intune in the past but whose serial number is no longer found among Intune managed devices (the managed device record was deleted).

	.PARAMETER OrphanedLastContactedDays
	Age threshold in days for orphaned devices. An Autopilot device is only treated as orphaned when its last contact with Intune was more than this number of days ago and its serial is no longer present in Intune. This prevents removing devices that contacted Intune recently.

	.PARAMETER CleanupNeverEnrolledDevices
	When enabled, removes never-enrolled Autopilot devices (devices that never contacted Intune).

	.PARAMETER NeverEnrolledAgeDays
	Age threshold in days for never-enrolled devices. Measured on the Device creation date.

	.PARAMETER EmailTo
	Optional email recipient address for the cleanup summary report. Leave empty to only write results to the runbook log.

	.PARAMETER EmailFrom
	The sender email address for the summary report. This is configured via Runbook Customizations.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"DeleteMode": {
				"DisplayName": "Deletion mode"
			},
			"GroupTagFilter": {
				"DisplayName": "Autopilot Group Tag Filter (comma-separated exact match, leave empty for all)"
			},
			"ManufacturerFilter": {
				"DisplayName": "Manufacturer Filter (comma-separated, substring match, leave empty for all)"
			},
			"ModelFilter": {
				"DisplayName": "Model Filter (comma-separated, substring match, leave empty for all)"
			},
			"ExcludeSerialNumbers": {
				"DisplayName": "Exclude Serial Numbers (comma-separated exact match, leave empty for none)"
			},
			"CleanupOrphanedDevices": {
				"DisplayName": "Clean up orphaned Autopilot devices"
			},
			"OrphanedLastContactedDays": {
				"DisplayName": "Orphaned device last-contacted threshold (days)"
			},
			"CleanupNeverEnrolledDevices": {
				"DisplayName": "Clean up never-enrolled Autopilot devices",
				"Select": {
					"Options": [
						{
							"Display": "Yes - remove aged never-enrolled devices",
							"Customization": {
								"Show": [
									"NeverEnrolledAgeDays"
								]
							},
							"ParameterValue": true
						},
						{
							"Display": "No",
							"Customization": {
								"Hide": [
									"NeverEnrolledAgeDays"
								]
							},
							"ParameterValue": false
						}
					]
				}
			},
			"NeverEnrolledAgeDays": {
				"DisplayName": "Never-enrolled device age threshold (days)",
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Email recipient for cleanup summary (optional)"
			},
			"EmailFrom": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.37.0" }

param (
    [ValidateSet("WhatIf (report only)", "Delete Autopilot device", "Delete Autopilot and Entra device")]
    [string]$DeleteMode = "WhatIf (report only)",

    [string]$GroupTagFilter = "",

    [string]$ManufacturerFilter = "",

    [string]$ModelFilter = "",

    [string]$ExcludeSerialNumbers = "",

    [bool]$CleanupOrphanedDevices = $true,

    [int]$OrphanedLastContactedDays = 90,

    [bool]$CleanupNeverEnrolledDevices = $false,

    [int]$NeverEnrolledAgeDays = 90,

    [string]$EmailTo = "",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "DeleteMode: $DeleteMode" -Verbose
Write-RjRbLog -Message "GroupTagFilter: $GroupTagFilter" -Verbose
Write-RjRbLog -Message "ManufacturerFilter: $ManufacturerFilter" -Verbose
Write-RjRbLog -Message "ModelFilter: $ModelFilter" -Verbose
Write-RjRbLog -Message "ExcludeSerialNumbers: $ExcludeSerialNumbers" -Verbose
Write-RjRbLog -Message "CleanupOrphanedDevices: $CleanupOrphanedDevices" -Verbose
Write-RjRbLog -Message "OrphanedLastContactedDays: $OrphanedLastContactedDays" -Verbose
Write-RjRbLog -Message "CleanupNeverEnrolledDevices: $CleanupNeverEnrolledDevices" -Verbose
Write-RjRbLog -Message "NeverEnrolledAgeDays: $NeverEnrolledAgeDays" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_" -ErrorAction Continue
    throw
}

# Connect-RjRbGraph is required because Send-RjReportEmail (optional email path) uses it for sender auth.
try {
    Connect-RjRbGraph
}
catch {
    Write-Error "Failed to connect via Connect-RjRbGraph (required for email sender auth): $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# --- Check 1: Email configuration consistency (email is optional) ---
if ($EmailTo -notlike "") {
    if ($EmailFrom -like "") {
        Write-RjRbLog -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -NoDebugOnly
        Write-Output "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
        $sendEmail = $false
    }
    else {
        Write-RjRbLog -Message "Email alert will be sent from '$EmailFrom' to '$EmailTo'." -Verbose
        Write-Output "Email alert requested: '$EmailTo'"
        $sendEmail = $true
    }
}
else {
    Write-RjRbLog -Message "EmailTo is empty - no email alert will be sent." -Verbose
    $sendEmail = $false
}

# --- Check 2: Age thresholds must be non-negative ---
if ($OrphanedLastContactedDays -lt 0) {
    Write-Error "OrphanedLastContactedDays must be 0 or greater. Submitted value: $OrphanedLastContactedDays." -ErrorAction Continue
    throw "Invalid parameter: OrphanedLastContactedDays cannot be negative."
}
if ($NeverEnrolledAgeDays -lt 0) {
    Write-Error "NeverEnrolledAgeDays must be 0 or greater. Submitted value: $NeverEnrolledAgeDays." -ErrorAction Continue
    throw "Invalid parameter: NeverEnrolledAgeDays cannot be negative."
}

# --- Check 3: At least one cleanup action enabled (advisory) ---
if (-not $CleanupOrphanedDevices -and -not $CleanupNeverEnrolledDevices) {
    Write-RjRbLog -Message "WARNING: Both CleanupOrphanedDevices and CleanupNeverEnrolledDevices are disabled. The runbook will report Autopilot device counts only - no devices will be removed." -NoDebugOnly
    Write-Output "WARNING: No cleanup action is enabled. The runbook will report counts only."
}

# --- Check 4: Parse the scope filters into trimmed, non-empty arrays ---
# Each filter is independent; an empty filter means "match all values for that dimension".
# When more than one is populated they are combined with AND (a device must match every set filter).
function ConvertTo-FilterList {
    param([string]$RawValue)
    if ($RawValue -like "") { return @() }
    return @($RawValue -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

$groupTagList = ConvertTo-FilterList -RawValue $GroupTagFilter
$manufacturerList = ConvertTo-FilterList -RawValue $ManufacturerFilter
$modelList = ConvertTo-FilterList -RawValue $ModelFilter
$excludeSerialList = ConvertTo-FilterList -RawValue $ExcludeSerialNumbers

# --- Resolve the deletion mode into the action flags used throughout the runbook ---
$whatIfMode = ($DeleteMode -eq "WhatIf (report only)")
$deleteEntraDevice = ($DeleteMode -eq "Delete Autopilot and Entra device")

# --- Status quo: show the effective run configuration ---
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

if ($whatIfMode) {
    Write-Output "Deletion Mode: WhatIf - no devices will be deleted, only reported"
}
elseif ($deleteEntraDevice) {
    Write-Output "Deletion Mode: Autopilot identity + matching Entra device will be deleted"
}
else {
    Write-Output "Deletion Mode: Autopilot identity only will be deleted"
}

if ($CleanupOrphanedDevices) {
    Write-Output "Cleanup Orphaned Devices: ENABLED"
    Write-Output "Orphaned Last-Contacted Threshold: $($OrphanedLastContactedDays) day(s)"
}
else {
    Write-Output "Cleanup Orphaned Devices: DISABLED"
}

if ($CleanupNeverEnrolledDevices) {
    Write-Output "Cleanup Never-Enrolled Devices: ENABLED"
    Write-Output "Never-Enrolled Age Threshold: $($NeverEnrolledAgeDays) day(s)"
}
else {
    Write-Output "Cleanup Never-Enrolled Devices: DISABLED"
}

if ($groupTagList.Count -gt 0) {
    Write-Output "Group Tag Filter (exact): $($groupTagList -join ', ')"
}
else {
    Write-Output "Group Tag Filter: all group tags (no filter applied)"
}

if ($manufacturerList.Count -gt 0) {
    Write-Output "Manufacturer Filter (substring): $($manufacturerList -join ', ')"
}
else {
    Write-Output "Manufacturer Filter: all manufacturers (no filter applied)"
}

if ($modelList.Count -gt 0) {
    Write-Output "Model Filter (substring): $($modelList -join ', ')"
}
else {
    Write-Output "Model Filter: all models (no filter applied)"
}

if ($excludeSerialList.Count -gt 0) {
    Write-Output "Exclude Serial Numbers (exact): $($excludeSerialList -join ', ')"
}
else {
    Write-Output "Exclude Serial Numbers: none"
}

if ($groupTagList.Count -gt 0 -and ($manufacturerList.Count -gt 0 -or $modelList.Count -gt 0) -or ($manufacturerList.Count -gt 0 -and $modelList.Count -gt 0)) {
    Write-Output "(Filters are combined with AND - a device must match every populated filter.)"
}

#endregion

########################################################
#region     Main Part
########################################################

# --- Pagination helper ---
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

# --- Helper: is this a usable Entra deviceId (not empty / not the all-zero GUID)? ---
function Test-ValidEntraDeviceId {
    param([string]$Id)
    return (-not [string]::IsNullOrWhiteSpace($Id)) -and ($Id -ne "00000000-0000-0000-0000-000000000000")
}

# --- Retrieve all Windows Autopilot device identities ---
Write-Output ""
Write-Output "Retrieving Autopilot device identities..."
$autopilotDevices = $null
try {
    # Beta endpoint is required: remediationState / remediationStateLastModifiedDateTime
    # (used for the never-enrolled age check) do not exist on the v1.0 resource.
    $autopilotDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error ("Access denied while retrieving Autopilot device identities. The managed identity is missing the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments (Microsoft Graph, app ID 00000003-0000-0000-c000-000000000000). Changes may take a few minutes to propagate.") -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementServiceConfig.ReadWrite.All on managed identity"
    }
    Write-Error "Failed to retrieve Autopilot device identities from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($autopilotDevices.Count) Autopilot device identities" -Verbose
Write-Output "Found $($autopilotDevices.Count) Autopilot device identities."

# --- Retrieve all Windows Intune managed devices ---
Write-Output "Retrieving Intune managed Windows devices..."
$intuneWindowsDevices = $null
try {
    $intuneWindowsDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,serialNumber,deviceName"
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error ("Access denied while retrieving Intune managed devices. The managed identity is missing the 'DeviceManagementManagedDevices.Read.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments.") -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementManagedDevices.Read.All on managed identity"
    }
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($intuneWindowsDevices.Count) Intune managed Windows devices" -Verbose
Write-Output "Found $($intuneWindowsDevices.Count) Intune managed Windows devices."

# --- Build a case-insensitive lookup of Intune serial numbers ---
$intuneSerialNumbers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($d in $intuneWindowsDevices) {
    if (-not [string]::IsNullOrWhiteSpace($d.serialNumber)) {
        [void]$intuneSerialNumbers.Add($d.serialNumber.Trim())
    }
}

# --- Apply scope filters (group tag / manufacturer / model), combined with AND ---
# groupTag, model and manufacturer are all returned by the collection query, so scoping can happen
# here before the per-device detail lookups. Group tag is matched exactly (case-insensitive); model
# and manufacturer are matched as case-insensitive substrings (e.g. "Dell" matches "Dell Inc.").
if ($groupTagList.Count -gt 0 -or $manufacturerList.Count -gt 0 -or $modelList.Count -gt 0) {
    $autopilotScoped = $autopilotDevices | Where-Object {
        $tag = if ($null -ne $_.groupTag) { $_.groupTag.Trim() } else { "" }
        $manufacturer = if ($null -ne $_.manufacturer) { $_.manufacturer } else { "" }
        $model = if ($null -ne $_.model) { $_.model } else { "" }

        $tagMatch = ($groupTagList.Count -eq 0) -or ($groupTagList -contains $tag)
        $manufacturerMatch = ($manufacturerList.Count -eq 0) -or ($manufacturerList | Where-Object { $manufacturer -like "*$_*" }).Count -gt 0
        $modelMatch = ($modelList.Count -eq 0) -or ($modelList | Where-Object { $model -like "*$_*" }).Count -gt 0

        $tagMatch -and $manufacturerMatch -and $modelMatch
    }
    $scopedCount = @($autopilotScoped).Count
    Write-RjRbLog -Message "Scope filters applied (AND): $scopedCount of $($autopilotDevices.Count) Autopilot devices match." -Verbose
    Write-Output "Scope filters applied: $scopedCount of $($autopilotDevices.Count) Autopilot devices in scope."
}
else {
    $autopilotScoped = $autopilotDevices
}

# --- Apply serial number exclusion (exact, case-insensitive) after the inclusion filters ---
if ($excludeSerialList.Count -gt 0) {
    $excludeSerialSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $excludeSerialList) { [void]$excludeSerialSet.Add($s) }

    $beforeExcludeCount = @($autopilotScoped).Count
    $autopilotScoped = $autopilotScoped | Where-Object {
        $serial = if ($null -ne $_.serialNumber) { $_.serialNumber.Trim() } else { "" }
        -not $excludeSerialSet.Contains($serial)
    }
    $afterExcludeCount = @($autopilotScoped).Count
    $excludedCount = $beforeExcludeCount - $afterExcludeCount
    Write-RjRbLog -Message "Serial number exclusion applied: $excludedCount device(s) excluded; $afterExcludeCount remain in scope." -Verbose
    Write-Output "Serial number exclusion applied: $excludedCount device(s) excluded; $afterExcludeCount remain in scope."
}

# --- Classify cleanup candidates ---
# Two independent, mutually exclusive categories, separated by whether the device ever contacted Intune:
#   Orphaned      = HAS contacted Intune before, last contact older than $OrphanedLastContactedDays,
#                   and its serial is no longer present among Intune managed devices.
#   NeverEnrolled = NEVER contacted Intune (lastContactedDateTime = 0001-01-01) and aged beyond
#                   $NeverEnrolledAgeDays (measured from remediationStateLastModifiedDateTime).
$orphanedCutoff = (Get-Date).AddDays(-$OrphanedLastContactedDays)
$neverEnrolledCutoff = (Get-Date).AddDays(-$NeverEnrolledAgeDays)
$cleanupResults = [System.Collections.Generic.List[object]]::new()
$seenIds = [System.Collections.Generic.HashSet[string]]::new()

Write-Output ""
Write-Output "Classifying non-enrolled Autopilot devices (one detail lookup per device - this may take a while in large tenants)..."

foreach ($ap in $autopilotScoped) {
    # Actively enrolled devices are never cleanup candidates, regardless of serial match or age.
    if ($ap.enrollmentState -eq "enrolled") {
        continue
    }

    # IMPORTANT: the windowsAutopilotDeviceIdentities *collection* query returns lastContactedDateTime
    # (and some other computed fields) as empty/0001-01-01 even for devices that have contacted Intune.
    # Only a single-entity GET returns the accurate value. Refresh each non-enrolled device here so the
    # contact history is correct; otherwise a previously-enrolled (orphaned) device would be misread as
    # never-enrolled. This costs one Graph call per non-enrolled device.
    $apDetail = $ap
    try {
        $apDetail = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($ap.id)" -Method GET -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not fetch full detail for Autopilot id $($ap.id); falling back to collection data (lastContactedDateTime may be inaccurate). Error: $($_.Exception.Message)" -NoDebugOnly
    }

    $serial = $apDetail.serialNumber

    # Determine contact history. A valid lastContactedDateTime (year > 1) means the device has
    # contacted Intune at least once. Never-contacted devices report 0001-01-01.
    $lastContact = $apDetail.lastContactedDateTime
    $lastContactDt = $null
    $lastContactDisplay = "Never"
    $hasContacted = $false
    if ($null -ne $lastContact -and "$lastContact" -ne "") {
        try {
            $lc = [DateTime]$lastContact
            if ($lc.Year -gt 1) {
                $lastContactDt = $lc
                $lastContactDisplay = $lc.ToString("yyyy-MM-dd HH:mm:ss")
                $hasContacted = $true
            }
        }
        catch {
            # Unparseable - treat as never contacted.
        }
    }

    # Orphaned: contacted before, contact is older than the threshold, serial gone from Intune.
    $serialMissingInIntune = (-not [string]::IsNullOrWhiteSpace($serial)) -and
        (-not $intuneSerialNumbers.Contains($serial.Trim()))
    $isOrphaned = $hasContacted -and $serialMissingInIntune -and ($lastContactDt -lt $orphanedCutoff)

    # Never-enrolled aging is measured from remediationStateLastModifiedDateTime, the only reliable
    # timestamp on a never-contacted Autopilot identity (lastContactedDateTime is 0001-01-01).
    # When no usable remediation timestamp exists (missing, 0001-01-01, or unparseable) the device
    # is treated as aged: a never-contacted record with no remediation activity is assumed stale.
    $remediationModified = $apDetail.remediationStateLastModifiedDateTime
    $remediationDisplay = "Unknown"
    $isAged = $true
    if ($null -ne $remediationModified -and "$remediationModified" -ne "") {
        try {
            $rm = [DateTime]$remediationModified
            if ($rm.Year -gt 1) {
                $remediationDisplay = $rm.ToString("yyyy-MM-dd HH:mm:ss")
                $isAged = $rm -lt $neverEnrolledCutoff
            }
        }
        catch {
            # Unparseable timestamp - leave $isAged = $true (treated as stale).
        }
    }
    $isNeverEnrolled = (-not $hasContacted) -and $isAged

    # Per-device decision trace (verbose). Enable verbose/debug logging on the runbook to see why a
    # specific device was or was not selected.
    Write-RjRbLog -Message ("Eval Autopilot id=$($ap.id) serial='$serial' state=$($apDetail.enrollmentState): " +
        "hasContacted=$hasContacted serialMissingInIntune=$serialMissingInIntune lastContact=$lastContactDisplay " +
        "remediation=$remediationDisplay isOrphaned=$isOrphaned isNeverEnrolled=$isNeverEnrolled") -Verbose

    $category = $null
    if ($CleanupNeverEnrolledDevices -and $isNeverEnrolled) {
        $category = "NeverEnrolled"
    }
    elseif ($CleanupOrphanedDevices -and $isOrphaned) {
        $category = "Orphaned"
    }

    if ($null -ne $category -and $seenIds.Add($ap.id)) {
        $cleanupResults.Add([PSCustomObject]@{
                SerialNumber          = $serial
                Model                 = $apDetail.model
                Manufacturer          = $apDetail.manufacturer
                GroupTag              = $apDetail.groupTag
                EnrollmentState       = $apDetail.enrollmentState
                LastContactedDateTime = $lastContactDisplay
                RemediationStateLastModified = $remediationDisplay
                AzureAdDeviceId       = $apDetail.azureActiveDirectoryDeviceId
                AutopilotId           = $ap.id
                Category              = $category
                Action                = if ($whatIfMode) { "WouldDelete" } else { "Pending" }
                EntraDeviceAction     = if (-not $deleteEntraDevice) { "Skipped (Autopilot only)" }
                                        elseif (-not (Test-ValidEntraDeviceId $apDetail.azureActiveDirectoryDeviceId)) { "No Entra device" }
                                        elseif ($whatIfMode) { "WouldDelete" }
                                        else { "Pending" }
            })
    }
}

$orphanedCount = ($cleanupResults | Where-Object { $_.Category -eq "Orphaned" }).Count
$neverEnrolledCount = ($cleanupResults | Where-Object { $_.Category -eq "NeverEnrolled" }).Count

Write-Output ""
Write-Output "Cleanup Candidates"
Write-Output "---------------------"
Write-Output "Orphaned (contacted >$OrphanedLastContactedDays day(s) ago, serial not in Intune): $orphanedCount"
Write-Output "Never-enrolled (never contacted, inactive >$NeverEnrolledAgeDays day(s)): $neverEnrolledCount"
Write-Output "Total candidates: $($cleanupResults.Count)"

foreach ($item in $cleanupResults) {
    Write-Output "  $($item.Category) | Serial: $($item.SerialNumber) | Model: $($item.Model) | Tag: $($item.GroupTag) | State: $($item.EnrollmentState) | LastContact: $($item.LastContactedDateTime)"
}

# --- Delete (or simulate) ---
$deletedCount = 0
$failedCount = 0
$wouldDeleteCount = 0
$entraDeletedCount = 0
$entraFailedCount = 0
$deleteFailedSerials = [System.Collections.Generic.List[string]]::new()

if ($cleanupResults.Count -gt 0) {
    if ($whatIfMode) {
        $wouldDeleteCount = $cleanupResults.Count
        Write-Output ""
        Write-Output "WhatIf mode is ENABLED - no devices were deleted. $wouldDeleteCount Autopilot identity/identities would be removed."
        if ($deleteEntraDevice) {
            $entraWouldDeleteCount = ($cleanupResults | Where-Object { $_.EntraDeviceAction -eq "WouldDelete" }).Count
            Write-Output "Of those, $entraWouldDeleteCount also have a matching Entra device that would be deleted."
        }
        Write-RjRbLog -Message "WhatIf mode enabled - $wouldDeleteCount Autopilot device(s) would be deleted." -Verbose
    }
    else {
        Write-Output ""
        Write-Output "Deleting $($cleanupResults.Count) Autopilot device identity/identities..."
        foreach ($candidate in $cleanupResults) {
            $deleteUri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($candidate.AutopilotId)"
            try {
                Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE -ErrorAction Stop
                $candidate.Action = "Deleted"
                $deletedCount++
                Write-RjRbLog -Message "Deleted Autopilot identity for serial '$($candidate.SerialNumber)' (ID: $($candidate.AutopilotId))." -Verbose
            }
            catch {
                $message = $_.Exception.Message
                if ($message -like "*404*" -or $message -like "*Not Found*") {
                    $candidate.Action = "Deleted"
                    $deletedCount++
                    Write-RjRbLog -Message "Autopilot identity for serial '$($candidate.SerialNumber)' was already deleted (404) - treated as removed." -Verbose
                }
                else {
                    $candidate.Action = "DeleteFailed"
                    $failedCount++
                    $deleteFailedSerials.Add($candidate.SerialNumber)
                    Write-RjRbLog -Message "WARNING: Failed to delete Autopilot identity for serial '$($candidate.SerialNumber)' (ID: $($candidate.AutopilotId)). Error: $message" -NoDebugOnly
                }
            }

            # When requested, also remove the matching Entra (Azure AD) device object. Once the
            # Autopilot identity is gone the Entra record can never re-enroll and is left behind as a
            # dead object, so it is cleaned up here. The Autopilot azureActiveDirectoryDeviceId is the
            # device's deviceId, not its directory object id, so the object id must be looked up first.
            if ($deleteEntraDevice -and (Test-ValidEntraDeviceId $candidate.AzureAdDeviceId)) {
                try {
                    $devLookup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$($candidate.AzureAdDeviceId)'&`$select=id,displayName" -Method GET -ErrorAction Stop
                    $devObj = $devLookup.value | Select-Object -First 1
                    if ($devObj -and $devObj.id) {
                        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices/$($devObj.id)" -Method DELETE -ErrorAction Stop
                        $candidate.EntraDeviceAction = "Deleted"
                        $entraDeletedCount++
                        Write-RjRbLog -Message "Deleted Entra device object '$($devObj.id)' (deviceId $($candidate.AzureAdDeviceId)) for serial '$($candidate.SerialNumber)'." -Verbose
                    }
                    else {
                        $candidate.EntraDeviceAction = "No Entra device"
                        Write-RjRbLog -Message "No Entra device object found for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)') - nothing to delete." -Verbose
                    }
                }
                catch {
                    $emessage = $_.Exception.Message
                    if ($emessage -like "*404*" -or $emessage -like "*Not Found*") {
                        $candidate.EntraDeviceAction = "Deleted"
                        $entraDeletedCount++
                        Write-RjRbLog -Message "Entra device for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)') was already deleted (404) - treated as removed." -Verbose
                    }
                    else {
                        $candidate.EntraDeviceAction = "DeleteFailed"
                        $entraFailedCount++
                        Write-RjRbLog -Message "WARNING: Failed to delete Entra device for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)'). Error: $emessage" -NoDebugOnly
                    }
                }
            }

            Start-Sleep -Milliseconds 200
        }
        Write-Output "Deletion complete. Autopilot removed: $deletedCount. Autopilot failed: $failedCount."
        if ($deleteEntraDevice) {
            Write-Output "Entra devices removed: $entraDeletedCount. Entra failed: $entraFailedCount."
        }
        if ($failedCount -gt 0) {
            Write-RjRbLog -Message "WARNING: $failedCount Autopilot deletion(s) failed and require manual review. Failed serials: $($deleteFailedSerials -join ', ')." -NoDebugOnly
        }
        if ($entraFailedCount -gt 0) {
            Write-RjRbLog -Message "WARNING: $entraFailedCount Entra device deletion(s) failed and require manual review." -NoDebugOnly
        }
    }
}
else {
    Write-Output ""
    Write-Output "No Autopilot devices matched the cleanup criteria. Nothing to do."
}

# --- Reporting: CSV export + optional email ---
$tempDir = $null
$csvFilePath = $null
if ($cleanupResults.Count -gt 0) {
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "AutopilotCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if (-not (Test-Path -Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    $csvFilePath = Join-Path -Path $tempDir -ChildPath "AutopilotCleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $cleanupResults | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    Write-RjRbLog -Message "Exported $($cleanupResults.Count) cleanup record(s) to $csvFilePath" -Verbose
}

# Tenant display name for the report
$tenantDisplayName = "Unknown Tenant"
try {
    $orgInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET -ErrorAction Stop
    if ($orgInfo.value -and $orgInfo.value[0].displayName) {
        $tenantDisplayName = $orgInfo.value[0].displayName
    }
}
catch {
    Write-Warning "Failed to retrieve tenant display name: $($_.Exception.Message)"
}

$runMode = if ($whatIfMode) { "WhatIf (report only)" }
elseif ($deleteEntraDevice) { "Execution (Autopilot + Entra devices deleted)" }
else { "Execution (Autopilot devices deleted)" }

if ($CleanupNeverEnrolledDevices) {
$NeverEnrolledOut = "- Never-enrolled candidates (never contacted, inactive >$NeverEnrolledAgeDays day(s)): **$neverEnrolledCount**"
}

if ($CleanupOrphanedDevices) {
$OrphandNoSerialOut = "- Orphaned candidates (last contacted >$OrphanedLastContactedDays day(s) ago, serial not in Intune): **$orphanedCount**"
}

if ($deleteEntraDevice) {
    if ($whatIfMode) {
        $entraWouldDeleteCount = ($cleanupResults | Where-Object { $_.EntraDeviceAction -eq "WouldDelete" }).Count
        $EntraOut = "- Matching Entra device objects that would be deleted: **$entraWouldDeleteCount**"
    }
    else {
        $EntraOut = "- Entra device objects deleted: **$entraDeletedCount** (failed: **$entraFailedCount**)"
    }
}

$markdownContent = @"
# Autopilot Device Cleanup Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

$OrphandNoSerialOut
$NeverEnrolledOut
- Total candidates: **$($cleanupResults.Count)**
- Autopilot identities deleted: **$deletedCount**
- Would delete (WhatIf): **$wouldDeleteCount**
- Failed: **$failedCount**
$EntraOut

The attached CSV lists every candidate device with its category and the action taken.
"@

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Tenant: $tenantDisplayName"
Write-Output "Run mode: $runMode"
Write-Output "Orphaned candidates: $orphanedCount"
Write-Output "Never-enrolled candidates: $neverEnrolledCount"
Write-Output "Deleted: $deletedCount | Would delete: $wouldDeleteCount | Failed: $failedCount"
if ($deleteEntraDevice) {
    Write-Output "Entra devices deleted: $entraDeletedCount | Entra failed: $entraFailedCount"
}

if ($sendEmail -and $cleanupResults.Count -gt 0) {
    $subject = "Autopilot Cleanup - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
    $attachments = @()
    if ($csvFilePath) { $attachments += $csvFilePath }
    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $subject -MarkdownContent $markdownContent -Attachments $attachments -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-RjRbLog -Message "Cleanup report email sent to '$EmailTo'." -Verbose
        Write-Output "Report email sent to: $EmailTo"
    }
    catch {
        Write-Error "Failed to send cleanup report email: $($_.Exception.Message)" -ErrorAction Continue
        Write-RjRbLog -Message "WARNING: Cleanup report email could not be sent to '$EmailTo'. The cleanup itself completed; review the error above." -NoDebugOnly
    }
}
elseif ($sendEmail -and $cleanupResults.Count -eq 0) {
    Write-Output "Email requested but there are no candidate devices - no report email sent."
}

#endregion

########################################################
#region     Cleanup
########################################################

# Remove the temporary CSV export, if one was created.
if ($csvFilePath -and (Test-Path -Path $csvFilePath)) {
    Remove-Item -Path $csvFilePath -Force -ErrorAction SilentlyContinue
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Disconnect Microsoft Graph (tolerate an already-disconnected session).
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
catch {
    # Already disconnected - nothing to do.
}

Write-Output "Done!"

#endregion
