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

	.PARAMETER IncludePrimaryUserDeleted
	Include devices whose Intune primary user has been deleted from Entra ID in the report. Intune mangles the user principal name of a deleted user by prefixing its object id, which would otherwise show up as a false Mismatch. Enabled by default.

	.PARAMETER EmailTo
	Recipient email address (or multiple comma-separated addresses) that should receive the report.

	.PARAMETER EmailFrom
	The sender email address. This is configured via the runbook customization setting and hidden in the portal.

	.PARAMETER UseDeviceScope
	Enable device scope filtering to include or exclude devices based on Entra device group membership.

	.PARAMETER IncludeDeviceGroup
	Only include devices that are members of this Entra device group in the report. Requires device scope filtering to be enabled.

	.PARAMETER ExcludeDeviceGroup
	Exclude devices that are members of this Entra device group from the report. Requires device scope filtering to be enabled.

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
			"IncludePrimaryUserDeleted": {
				"DisplayName": "Include Deleted Primary Users",
                "Hide": true
			},
			"UseDeviceScope": {
				"DisplayName": "Use Device Scope Filtering",
				"Hide": true
			},
			"IncludeDeviceGroup": {
				"DisplayName": "Devices to include (Group)",
				"Hide": true
			},
			"ExcludeDeviceGroup": {
				"DisplayName": "Devices to exclude (Group)",
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
		},
		"ParameterList": [
			{
				"DisplayName": "(Optional) Enable device scope filtering to include or exclude devices based on Entra device group membership.",
				"DisplayAfter": "IncludePrimaryUserDeleted",
				"Select": {
					"Options": [
						{
							"Display": "Yes - filter by device group membership",
							"Customization": {
								"Hide": [],
								"Show": ["IncludeDeviceGroup", "ExcludeDeviceGroup"],
								"Default": {
									"UseDeviceScope": true
								}
							}
						},
						{
							"Display": "No - include all devices",
							"Customization": {
								"Hide": ["IncludeDeviceGroup", "ExcludeDeviceGroup"],
								"Default": {
									"UseDeviceScope": false
								}
							},
							"ParameterValue": false
						}
					]
				}
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param (
    [int]$SyncThresholdDays = 30,

    [string]$DeviceNamePrefix = "",

    [bool]$IncludeMismatches = $true,

    [bool]$IncludeMissingInRealmJoin = $false,

    [bool]$IncludeMissingInIntune = $false,

    [bool]$IncludePrimaryUserDeleted = $false,

    [bool]$UseDeviceScope = $false,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Devices from Group" } )]
    [string]$IncludeDeviceGroup,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Devices from Group" } )]
    [string]$ExcludeDeviceGroup,

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

$Version = "1.4.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "SyncThresholdDays: $SyncThresholdDays" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "IncludeMismatches: $IncludeMismatches" -Verbose
Write-RjRbLog -Message "IncludeMissingInRealmJoin: $IncludeMissingInRealmJoin" -Verbose
Write-RjRbLog -Message "IncludeMissingInIntune: $IncludeMissingInIntune" -Verbose
Write-RjRbLog -Message "IncludePrimaryUserDeleted: $IncludePrimaryUserDeleted" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "UseDeviceScope: $UseDeviceScope" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "ExcludeDeviceGroup: $ExcludeDeviceGroup" -Verbose

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

# Optional device scope filtering: resolve Entra device group membership up front so the
# Data Processing region can drop devices that should not affect the report. Group members of
# type #microsoft.graph.device expose their Entra Device ID via the 'deviceId' property, which
# corresponds to the managedDevice 'azureADDeviceId' / RealmJoin 'entraDeviceId'.
$includeDeviceIds = @()
$excludeDeviceIds = @()

if ($UseDeviceScope) {
    Write-Output ""
    Write-Output "Get Device Scope Groups"
    Write-Output "---------------------"

    if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) {
        Write-Output "Retrieving members of the include device group..."
        try {
            $includeGroupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeDeviceGroup/members?`$select=id,deviceId,displayName"
            $includeMembers = Get-GraphPagedResult -Uri $includeGroupUri
            $includeDeviceIds = @($includeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { $_.deviceId.ToLower() })
            Write-Output "Include device group contains $($includeDeviceIds.Count) device(s)."
        }
        catch {
            Write-Error "Failed to retrieve members of the include device group ('$IncludeDeviceGroup'): $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to retrieve include device group membership"
        }
    }

    if (-not [string]::IsNullOrEmpty($ExcludeDeviceGroup)) {
        Write-Output "Retrieving members of the exclude device group..."
        try {
            $excludeGroupUri = "https://graph.microsoft.com/v1.0/groups/$ExcludeDeviceGroup/members?`$select=id,deviceId,displayName"
            $excludeMembers = Get-GraphPagedResult -Uri $excludeGroupUri
            $excludeDeviceIds = @($excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { $_.deviceId.ToLower() })
            Write-Output "Exclude device group contains $($excludeDeviceIds.Count) device(s)."
        }
        catch {
            Write-Error "Failed to retrieve members of the exclude device group ('$ExcludeDeviceGroup'): $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to retrieve exclude device group membership"
        }
    }
}

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

    # Detect a deleted Entra primary user: when the primary user no longer exists in Entra ID,
    # Intune mangles managedDevice.userPrincipalName by prefixing the user's object id (a GUID
    # without dashes, 32 hex chars) in front of the original UPN, e.g.
    # "702fabaa7fef412ea14ed0bea71e8729heidi.kabel@contoso.com". Without special handling this
    # would surface as a false Mismatch against RealmJoin's clean, cached userName.
    $intunePrimaryUserDeleted = $false
    $intunePrimaryUser = if ([string]::IsNullOrEmpty($intuneDevice.userPrincipalName)) { "(none)" } else { $intuneDevice.userPrincipalName }
    if ($intuneDevice.userPrincipalName -match '^[0-9a-fA-F]{32}(?<upn>.+@.+)$') {
        $intunePrimaryUserDeleted = $true
        $intunePrimaryUser = $Matches['upn']
    }

    # Match against RealmJoin by entraDeviceId (Azure AD Device ID) first, then by intuneDeviceId.
    $rjDevice = $null
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) {
        $rjDevice = $rjDevicesByEntraId[$intuneDevice.azureADDeviceId.ToLower()]
    }
    if (-not $rjDevice) {
        $rjDevice = $rjDevices | Where-Object { $_.intuneDeviceId -eq $intuneDevice.id } | Select-Object -First 1
    }

    $rjPrimaryUser = if ($rjDevice) { $rjDevice.users | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1 } else { $null }
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { $rjPrimaryUser.userName } else { "(none)" }

    # A deleted Intune primary user is its own category and takes precedence: it is not a real
    # configuration drift but a cleanup candidate. Otherwise a Mismatch is only possible when
    # RealmJoin actually has a user flagged isPrimary = true; a device absent from RealmJoin (or
    # whose primary user has never logged in and therefore cannot be detected) is MissingInRealmJoin.
    if ($intunePrimaryUserDeleted) {
        $status = "PrimaryUserDeleted"
    }
    elseif ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) {
        $status = if ($intunePrimaryUser.ToLower() -eq $rjPrimaryUserName.ToLower()) { "Match" } else { "Mismatch" }
    }
    else {
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

# Apply optional device scope filtering by Entra device group membership. This runs after the full
# report set (including MissingInIntune orphans) is assembled so excluded devices do not affect any
# summary counts below. Devices are matched on their Entra Device ID (AzureAdDeviceId).
if ($UseDeviceScope -and (($includeDeviceIds.Count -gt 0) -or ($excludeDeviceIds.Count -gt 0))) {
    $beforeScopeCount = $reportData.Count
    $reportData = @($reportData | Where-Object {
            $deviceEntraId = if (-not [string]::IsNullOrEmpty($_.AzureAdDeviceId)) { $_.AzureAdDeviceId.ToLower() } else { $null }

            # Include filter: keep only devices that are members of the include group.
            if (($includeDeviceIds.Count -gt 0) -and (($null -eq $deviceEntraId) -or ($deviceEntraId -notin $includeDeviceIds))) {
                return $false
            }

            # Exclude filter: drop devices that are members of the exclude group.
            if (($excludeDeviceIds.Count -gt 0) -and ($null -ne $deviceEntraId) -and ($deviceEntraId -in $excludeDeviceIds)) {
                return $false
            }

            return $true
        })
    Write-RjRbLog -Message "Device scope filtering applied: $beforeScopeCount -> $($reportData.Count) device(s)" -Verbose
    Write-Output "Device scope filtering applied: $beforeScopeCount device(s) reduced to $($reportData.Count)."
}

# Build the set of difference statuses the caller asked to include in the report.
$includedStatuses = [System.Collections.Generic.List[string]]::new()
if ($IncludeMismatches) { $includedStatuses.Add("Mismatch") }
if ($IncludeMissingInRealmJoin) { $includedStatuses.Add("MissingInRealmJoin") }
if ($IncludeMissingInIntune) { $includedStatuses.Add("MissingInIntune") }
if ($IncludePrimaryUserDeleted) { $includedStatuses.Add("PrimaryUserDeleted") }

if ($includedStatuses.Count -eq 0) {
    Write-RjRbLog -Message "WARNING: No difference categories are enabled (IncludeMismatches, IncludeMissingInRealmJoin, IncludeMissingInIntune, IncludePrimaryUserDeleted are all false). No differences will be reported." -Verbose
    Write-Output "WARNING: No difference categories are enabled - the report will contain no differences."
}

Write-RjRbLog -Message "Included difference statuses: $($includedStatuses -join ', ')" -Verbose

$differences = @($reportData | Where-Object { $includedStatuses -contains $_.Status })

$totalEvaluated = $reportData.Count
$matchCount = @($reportData | Where-Object { $_.Status -eq "Match" }).Count
$mismatchCount = @($reportData | Where-Object { $_.Status -eq "Mismatch" }).Count
$missingInRjCount = @($reportData | Where-Object { $_.Status -eq "MissingInRealmJoin" }).Count
$missingInIntuneCount = @($reportData | Where-Object { $_.Status -eq "MissingInIntune" }).Count
$primaryUserDeletedCount = @($reportData | Where-Object { $_.Status -eq "PrimaryUserDeleted" }).Count

Write-RjRbLog -Message "Total evaluated: $totalEvaluated; Match: $matchCount; Mismatch: $mismatchCount; MissingInRealmJoin: $missingInRjCount; MissingInIntune: $missingInIntuneCount; PrimaryUserDeleted: $primaryUserDeletedCount" -Verbose

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
Write-Output "Primary User Deleted: $primaryUserDeletedCount"

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
    # (IncludeMismatches / IncludeMissingInRealmJoin / IncludeMissingInIntune /
    # IncludePrimaryUserDeleted). Total Devices Evaluated is always shown for context.
    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("- **Total Devices Evaluated**: $totalEvaluated")
    if ($IncludeMismatches) { $summaryLines.Add("- **Mismatches**: $mismatchCount") }
    if ($IncludeMissingInRealmJoin) { $summaryLines.Add("- **Missing in RealmJoin**: $missingInRjCount") }
    if ($IncludeMissingInIntune) { $summaryLines.Add("- **Missing in Intune**: $missingInIntuneCount") }
    if ($IncludePrimaryUserDeleted) { $summaryLines.Add("- **Primary User Deleted (Entra)**: $primaryUserDeletedCount") }
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

    $markdownContent += "`n---`n`n*This email was automatically generated. Please do not reply to this email.*`n"

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
