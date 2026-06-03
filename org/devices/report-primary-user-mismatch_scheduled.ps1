<#
	.SYNOPSIS
	Compare primary user assignments in Intune against RealmJoin for Windows managed devices

	.DESCRIPTION
	For Windows managed devices, this scheduled report compares the primary user recorded in Intune against the primary user recorded in the RealmJoin customer API. It correlates the two datasets per device, flags any device where the primary user differs, and emails the differences with a CSV attachment.

	.NOTES
	Prerequisites:
	- An Azure Automation Account shared credential named exactly "RJAPI" must be created manually
	  before scheduling. Set the username and password to match a RealmJoin customer API account
	  (see https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication).
	- The Automation Account managed identity must have the following Graph application permissions
	  assigned: DeviceManagementManagedDevices.Read.All, Mail.Send, Organization.Read.All.
	- The RJReport.EmailSender setting must be configured with a valid sender address before the first run.
	- No email is sent when the two datasets are in sync; an empty run is not an error.

	.PARAMETER SyncThresholdDays
	Number of days to look back for the Intune last-sync filter. Only Windows devices that have synced within this many days are evaluated.

	.PARAMETER DeviceNamePrefix
	Optional device name prefix to filter the report to a specific subset of devices. Leave blank to include all devices.

	.PARAMETER IncludeMismatches
	Include devices whose primary user differs between Intune and RealmJoin in the report. Enabled by default.

	.PARAMETER IncludeMissingInRealmJoin
	Include devices that exist in Intune but have no matching device in RealmJoin in the report. Disabled by default.

	.PARAMETER IncludeMissingInIntune
	Include devices that exist in RealmJoin but have no matching Intune device in the report. Disabled by default.

	.PARAMETER EmailTo
	Recipient email address (or multiple comma-separated addresses) that should receive the report.

	.PARAMETER EmailFrom
	The sender email address. This is configured via the runbook customization setting and hidden in the portal.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SyncThresholdDays": {
				"DisplayName": "Intune Last Sync (days)"
			},
			"DeviceNamePrefix": {
				"DisplayName": "Device Name Prefix (optional)"
			},
			"IncludeMismatches": {
				"DisplayName": "Include Mismatches",
                "Hide": true
			},
			"IncludeMissingInRealmJoin": {
				"DisplayName": "Include Missing in RealmJoin",
                "Hide": true
			},
			"IncludeMissingInIntune": {
				"DisplayName": "Include Missing in Intune",
                "Hide": true
			},
			"EmailTo": {
				"DisplayName": "Send Report To"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.6" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.37.0" }

param (
    [int]$SyncThresholdDays = 30,

    [string]$DeviceNamePrefix = "",

    [bool]$IncludeMismatches = $true,

    [bool]$IncludeMissingInRealmJoin = $false,

    [bool]$IncludeMissingInIntune = $false,

    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

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

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "SyncThresholdDays: $SyncThresholdDays" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "IncludeMismatches: $IncludeMismatches" -Verbose
Write-RjRbLog -Message "IncludeMissingInRealmJoin: $IncludeMissingInRealmJoin" -Verbose
Write-RjRbLog -Message "IncludeMissingInIntune: $IncludeMissingInIntune" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# Retrieve the RealmJoin API credential from the Automation Account shared credentials store.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
Write-RjRbLog -Message "Retrieving Automation Account credential 'RJAPI' for RealmJoin API authentication." -Verbose
$rjApiCredential = Get-AutomationPSCredential -Name "RJAPI"

if ($null -eq $rjApiCredential) {
    Write-Error @"
The Automation Account shared credential named 'RJAPI' is missing.
See the runbook documentation https://docs.realmjoin.com/automation/runbooks/runbook-references/org/devices/report-primary-user-mismatch_scheduled for full setup instructions.

Step-by-step setup:
  1. If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
  2. In the Azure portal, open the Azure Automation Account used for runbooks
  3. Navigate to Shared Resources > Credentials
  4. Click 'Add a credential'
  5. Set the name to exactly: RJAPI
  6. Enter the RealmJoin API username and password
  7. Save and re-run this runbook
"@ -ErrorAction Continue
    throw "Automation Account credential 'RJAPI' not found. Cannot authenticate to the RealmJoin API without it."
}

Write-RjRbLog -Message "Credential 'RJAPI' retrieved successfully. API username: '$($rjApiCredential.UserName)'." -Verbose
Write-Output "RealmJoin API credential 'RJAPI' - OK"

if ($SyncThresholdDays -le 0) {
    Write-Error "The value provided for 'SyncThresholdDays' is '$SyncThresholdDays', which is not valid. SyncThresholdDays must be greater than 0." -ErrorAction Continue
    throw "SyncThresholdDays must be greater than 0. Received: '$SyncThresholdDays'."
}

Write-Output "SyncThresholdDays ($SyncThresholdDays) - OK"

if ([string]::IsNullOrWhiteSpace($EmailTo)) {
    Write-Error "The 'EmailTo' parameter is empty or contains only whitespace. A valid recipient email address is required so the report can be delivered." -ErrorAction Continue
    throw "EmailTo must be a non-empty, non-whitespace email address. Received: '$EmailTo'."
}

Write-Output "EmailTo ($EmailTo) - OK"

Write-Output ""
Write-Output "Parameter Validation completed successfully."

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $_" -ErrorAction Continue
    throw
}

# Connect-RjRbGraph is required for Send-RjReportEmail email sender auth.
Write-Output "Connecting to RJ RunbookHelper Graph session (required for Send-RjReportEmail)..."
try {
    Connect-RjRbGraph -ErrorAction Stop
}
catch {
    Write-Error "Failed to establish the RJ RunbookHelper Graph session. Send-RjReportEmail will not be available. Ensure the managed identity has the Mail.Send app role assignment. Error: $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Intune Managed Devices"
Write-Output "---------------------"

# Build ISO8601 UTC threshold from the SyncThresholdDays parameter.
$thresholdDate = (Get-Date).AddDays(-$SyncThresholdDays)
$isoThresholdDate = $thresholdDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-RjRbLog -Message "Sync threshold date (UTC): $isoThresholdDate (last $SyncThresholdDays days)" -Verbose

# Server-side $filter (OS + lastSync) and $select keep the payload small for large tenants.
# The device-name-prefix filter is applied client-side in the Data Processing region.
# managedDevice.userPrincipalName / userId IS the Intune primary user - no per-device call needed.
$baseUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$filterQuery = "`$filter=operatingSystem eq 'Windows' and lastSyncDateTime ge $isoThresholdDate"
$selectQuery = "`$select=id,deviceName,azureADDeviceId,userId,userPrincipalName,operatingSystem,lastSyncDateTime"
$graphUri = "$baseUri`?$filterQuery&$selectQuery"

try {
    $intuneDevices = Get-GraphPagedResult -Uri $graphUri
}
catch {
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve Intune device inventory"
}

Write-Output "Retrieved $($intuneDevices.Count) Windows device(s) synced in the last $SyncThresholdDays day(s)."
Write-RjRbLog -Message "Intune devices retrieved: $($intuneDevices.Count)" -Verbose

Write-Output ""
Write-Output "Get RealmJoin Devices"
Write-Output "---------------------"

# Authenticate to the RealmJoin customer API with Basic Auth using the 'RJAPI' credential.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
$rjApiUri = "https://customer-api.realmjoin.com/device/list"
$rjApiPassword = $rjApiCredential.GetNetworkCredential().Password
$rjAuthRaw = "$($rjApiCredential.UserName):$rjApiPassword"
$rjAuthHeader = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rjAuthRaw))
$rjHeaders = @{
    Authorization = $rjAuthHeader
    Accept        = "application/json"
}

try {
    $rjResponse = Invoke-RestMethod -Uri $rjApiUri -Method GET -Headers $rjHeaders -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve devices from the RealmJoin API ($rjApiUri): $($_.Exception.Message). Verify the 'RJAPI' credential is valid and the API is reachable." -ErrorAction Continue
    throw "Unable to retrieve RealmJoin device list"
}

# Normalize the response to a plain array (the API may return a bare array or a { value: [...] } wrapper).
if ($null -eq $rjResponse) {
    $rjDevices = @()
}
elseif ($rjResponse.PSObject -and ($rjResponse.PSObject.Properties.Name -contains 'value')) {
    $rjDevices = @($rjResponse.value)
}
else {
    $rjDevices = @($rjResponse)
}

Write-Output "Retrieved $($rjDevices.Count) device(s) from the RealmJoin API."
Write-RjRbLog -Message "RealmJoin devices retrieved: $($rjDevices.Count)" -Verbose

#endregion

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Processing device data correlation..."
Write-Output "---------------------"

# Build a lookup of RealmJoin devices keyed by entraDeviceId (lowercased) for O(1) matching.
$rjDevicesByEntraId = @{}
foreach ($rjDevice in $rjDevices) {
    if (-not [string]::IsNullOrEmpty($rjDevice.entraDeviceId)) {
        $rjDevicesByEntraId[$rjDevice.entraDeviceId.ToLower()] = $rjDevice
    }
}

# Apply the DeviceNamePrefix filter (client-side, case-insensitive).
$filteredIntuneDevices = if ([string]::IsNullOrEmpty($DeviceNamePrefix)) {
    $intuneDevices
}
else {
    $intuneDevices | Where-Object { $_.deviceName -like "$DeviceNamePrefix*" }
}

Write-RjRbLog -Message "Intune devices after name-prefix filter: $($filteredIntuneDevices.Count)" -Verbose

$reportData = @()
$reportData = $filteredIntuneDevices | ForEach-Object {
    $intuneDevice = $_
    $intunePrimaryUser = if ([string]::IsNullOrEmpty($intuneDevice.userPrincipalName)) { "(none)" } else { $intuneDevice.userPrincipalName }

    # Match against RealmJoin by entraDeviceId (Azure AD Device ID) first, then by intuneDeviceId.
    $rjDevice = $null
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) {
        $rjDevice = $rjDevicesByEntraId[$intuneDevice.azureADDeviceId.ToLower()]
    }
    if (-not $rjDevice) {
        $rjDevice = $rjDevices | Where-Object { $_.intuneDeviceId -eq $intuneDevice.id } | Select-Object -First 1
    }

    # A Mismatch is only possible when RealmJoin actually has a user flagged isPrimary = true.
    # If the matched RealmJoin device has no primary user (device absent from RealmJoin, or the
    # primary user has never logged in and therefore cannot be detected), it is NOT a Mismatch -
    # it is classified as MissingInRealmJoin.
    $rjPrimaryUser = if ($rjDevice) { $rjDevice.users | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1 } else { $null }
    if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) {
        $rjPrimaryUserName = $rjPrimaryUser.userName
        $status = if ($intunePrimaryUser.ToLower() -eq $rjPrimaryUserName.ToLower()) { "Match" } else { "Mismatch" }
    }
    else {
        $rjPrimaryUserName = "(none)"
        $status = "MissingInRealmJoin"
    }

    $lastSync = if ($intuneDevice.lastSyncDateTime) { (Get-Date $intuneDevice.lastSyncDateTime).ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }

    [PSCustomObject]@{
        DeviceName           = $intuneDevice.deviceName
        AzureAdDeviceId      = $intuneDevice.azureADDeviceId
        IntuneDeviceId       = $intuneDevice.id
        IntunePrimaryUser    = $intunePrimaryUser
        RealmJoinPrimaryUser = $rjPrimaryUserName
        Status               = $status
        LastSyncDateTime     = $lastSync
    }
}

# Ensure $reportData is always an array even if 0 or 1 item.
$reportData = @($reportData)

Write-RjRbLog -Message "Processed $($reportData.Count) Intune devices for correlation analysis" -Verbose

# Surface RealmJoin devices that had no Intune counterpart (in-scope after the name filter).
$intuneEntraIds = @($filteredIntuneDevices | ForEach-Object { if (-not [string]::IsNullOrEmpty($_.azureADDeviceId)) { $_.azureADDeviceId.ToLower() } })
foreach ($orphanRj in $rjDevices) {
    if ([string]::IsNullOrEmpty($orphanRj.entraDeviceId)) { continue }
    if ($intuneEntraIds -contains $orphanRj.entraDeviceId.ToLower()) { continue }
    $rjPrimaryUser = $orphanRj.users | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { $rjPrimaryUser.userName } else { "(none)" }
    $reportData += [PSCustomObject]@{
        DeviceName           = "N/A"
        AzureAdDeviceId      = $orphanRj.entraDeviceId
        IntuneDeviceId       = $orphanRj.intuneDeviceId
        IntunePrimaryUser    = "(none)"
        RealmJoinPrimaryUser = $rjPrimaryUserName
        Status               = "MissingInIntune"
        LastSyncDateTime     = "N/A"
    }
}

# Build the set of difference statuses the caller asked to include in the report.
$includedStatuses = [System.Collections.Generic.List[string]]::new()
if ($IncludeMismatches) { $includedStatuses.Add("Mismatch") }
if ($IncludeMissingInRealmJoin) { $includedStatuses.Add("MissingInRealmJoin") }
if ($IncludeMissingInIntune) { $includedStatuses.Add("MissingInIntune") }

if ($includedStatuses.Count -eq 0) {
    Write-RjRbLog -Message "WARNING: No difference categories are enabled (IncludeMismatches, IncludeMissingInRealmJoin, IncludeMissingInIntune are all false). No differences will be reported." -Verbose
    Write-Output "WARNING: No difference categories are enabled - the report will contain no differences."
}

Write-RjRbLog -Message "Included difference statuses: $($includedStatuses -join ', ')" -Verbose

$differences = @($reportData | Where-Object { $includedStatuses -contains $_.Status })

$totalEvaluated = $reportData.Count
$matchCount = @($reportData | Where-Object { $_.Status -eq "Match" }).Count
$mismatchCount = @($reportData | Where-Object { $_.Status -eq "Mismatch" }).Count
$missingInRjCount = @($reportData | Where-Object { $_.Status -eq "MissingInRealmJoin" }).Count
$missingInIntuneCount = @($reportData | Where-Object { $_.Status -eq "MissingInIntune" }).Count

Write-RjRbLog -Message "Total evaluated: $totalEvaluated; Match: $matchCount; Mismatch: $mismatchCount; MissingInRealmJoin: $missingInRjCount; MissingInIntune: $missingInIntuneCount" -Verbose

#endregion

########################################################
#region     Output/Export
########################################################

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Total Devices Evaluated: $totalEvaluated"
Write-Output "Matching: $matchCount"
Write-Output "Mismatches: $mismatchCount"
Write-Output "Missing in RealmJoin: $missingInRjCount"
Write-Output "Missing in Intune: $missingInIntuneCount"

$tempDir = $null
$csvFilePath = $null

# Cap the inline "Devices with Differences" listing at this many rows; the full set is always in the CSV.
$maxDisplayDevices = 10
$displayDifferences = @($differences | Select-Object -First $maxDisplayDevices)

if ($differences.Count -gt 0) {
    Write-Output ""
    Write-Output "Devices with Primary User Differences"
    Write-Output "---------------------"
    $displayDifferences | Format-Table -AutoSize -Property DeviceName, AzureAdDeviceId, IntunePrimaryUser, RealmJoinPrimaryUser, Status, LastSyncDateTime
    if ($differences.Count -gt $maxDisplayDevices) {
        Write-Output "Showing the first $maxDisplayDevices of $($differences.Count) device(s) with differences. See the attached CSV for the complete list."
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    $csvFilePath = Join-Path $tempDir "$(Get-Date -Format 'yyyyMMdd_HHmmss')_PrimaryUserMismatch.csv"
    $differences | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    Write-RjRbLog -Message "Exported $($differences.Count) differing devices to CSV: $csvFilePath" -Verbose
    Write-Output "CSV file created: $csvFilePath"
}
else {
    Write-Output ""
    Write-Output "No primary user differences detected - Intune and RealmJoin are in sync."
    Write-Output "Email report skipped (no differences found)."
}

#endregion

########################################################
#region     Email Report
########################################################

if ($differences.Count -gt 0) {
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        $tenantDisplayName = $tenantInfo.value[0].displayName ?? "Tenant"
    }
    catch {
        Write-Warning "Failed to retrieve tenant display name: $_"
        $tenantDisplayName = "Tenant"
    }

    # Build the summary so it only lists the difference categories the caller enabled
    # (IncludeMismatches / IncludeMissingInRealmJoin / IncludeMissingInIntune). Total Devices
    # Evaluated is always shown for context.
    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("- **Total Devices Evaluated**: $totalEvaluated")
    if ($IncludeMismatches) { $summaryLines.Add("- **Mismatches**: $mismatchCount") }
    if ($IncludeMissingInRealmJoin) { $summaryLines.Add("- **Missing in RealmJoin**: $missingInRjCount") }
    if ($IncludeMissingInIntune) { $summaryLines.Add("- **Missing in Intune**: $missingInIntuneCount") }
    $summaryBlock = $summaryLines -join "`n"

    $markdownContent = @"
# Primary User Mismatch Report

## Summary
$summaryBlock

## Devices with Differences
A total of $($differences.Count) device(s) differ between Intune and RealmJoin. Showing up to $maxDisplayDevices below; the full list is in the attached CSV.

| Device Name | Entra Device ID | Intune Primary User | RealmJoin Primary User | Status | Last Sync |
|---|---|---|---|---|---|
"@

    foreach ($device in $displayDifferences) {
        $markdownContent += "`n| $($device.DeviceName) | $($device.AzureAdDeviceId) | $($device.IntunePrimaryUser) | $($device.RealmJoinPrimaryUser) | $($device.Status) | $($device.LastSyncDateTime) |"
    }

    if ($differences.Count -gt $maxDisplayDevices) {
        $markdownContent += "`n`n_Showing the first $maxDisplayDevices of $($differences.Count) device(s) with differences. See the attached CSV for the complete list._"
    }

    $markdownContent += "`n`nSee the attached CSV for full details.`n"

    $emailSubject = "Primary User Mismatch Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
    $attachments = @($csvFilePath)

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -Attachments $attachments -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-RjRbLog -Message "Email report sent successfully to: $EmailTo" -Verbose
        Write-Output "Report sent to: $EmailTo"
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}
else {
    Write-RjRbLog -Message "No differences found - email report skipped" -Verbose
}

#endregion

########################################################
#region     Cleanup
########################################################

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Removed temporary export directory: $tempDir" -Verbose
}

# Connect-RjRbGraph session is managed internally by RealmJoin.RunbookHelper - no explicit disconnect needed.
Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
