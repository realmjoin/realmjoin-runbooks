<#
	.SYNOPSIS
	Report devices whose RealmJoin agent stopped reporting

	.DESCRIPTION
	Compares, for Windows devices, when RealmJoin last saw the device with when it last synced with Intune. A device that Intune saw well after RealmJoin last did points to a RealmJoin agent that is missing, blocked or broken. Devices RealmJoin has never seen and devices known to only one side can be listed as well. The report can be sent by email or provided as a download link.

	.PARAMETER SyncThresholdDays
	Only devices that synced with Intune within this many days are compared. Devices that stopped syncing altogether belong in the stale device report instead.

	.PARAMETER AgentContactThresholdDays
	A device counts as agent stale when Intune saw it at least this many days after RealmJoin last did. Short gaps are normal, as the agent only reports while a user is signed in.

	.PARAMETER DeviceNamePrefix
	Only devices whose name starts with this text. Leave empty for all.

	.PARAMETER IncludeAgentStale
	Lists devices that Intune saw well after RealmJoin last did, the sign of an agent that no longer reports.

	.PARAMETER IncludeNeverSeen
	Lists devices RealmJoin knows but has never seen a signed-in user on, for example devices that were enrolled but not used yet.

	.PARAMETER IncludeMissingInRealmJoin
	Lists devices that exist in Intune but not in RealmJoin.

	.PARAMETER IncludeMissingInIntune
	Lists devices that exist in RealmJoin but did not sync with Intune within the sync window. Not available together with a device name prefix.

	.PARAMETER IncludeDeviceGroup
	Only devices in this Entra ID group. Leave empty for all devices.

	.PARAMETER ExcludeDeviceGroup
	Skips devices in this Entra ID group, for example kiosk or shared devices that rarely have a signed-in user. Leave empty to skip none.

	.PARAMETER EmailFrom
	Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

	.PARAMETER BrandingHeaderImageUrl
	Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

	.PARAMETER BrandingFooterImageUrl
	Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

	.PARAMETER BrandingFooterLink
	Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

	.PARAMETER BrandingAccentColor
	Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER BrandingTextColor
	Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

	.PARAMETER ReportFileFormat
	Deliver the report as CSV, as an Excel workbook, or both.

	.PARAMETER CreateDownloadLink
	Also upload the report and return a download link that expires after a few days.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SyncThresholdDays": {
				"DisplayName": "Intune last sync within (days)"
			},
			"AgentContactThresholdDays": {
				"DisplayName": "Allowed gap to RealmJoin last seen (days)"
			},
			"DeviceNamePrefix": {
				"DisplayName": "Device name prefix"
			},
			"IncludeAgentStale": {
				"Hide": true
			},
			"IncludeNeverSeen": {
				"DisplayName": "Include devices RealmJoin has never seen?",
				"SelectSimple": {
					"Yes": true,
					"No": false
				}
			},
			"IncludeMissingInRealmJoin": {
				"DisplayName": "Include devices missing in RealmJoin?",
				"SelectSimple": {
					"Yes": true,
					"No": false
				}
			},
			"IncludeMissingInIntune": {
				"DisplayName": "Include devices missing in Intune?",
				"SelectSimple": {
					"Yes": true,
					"No": false
				}
			},
			"IncludeDeviceGroup": {
				"DisplayName": "Include devices from group"
			},
			"ExcludeDeviceGroup": {
				"DisplayName": "Exclude devices from group"
			},
			"EmailFrom": {
				"Hide": true
			},
			"BrandingHeaderImageUrl": {
				"Hide": true
			},
			"BrandingFooterImageUrl": {
				"Hide": true
			},
			"BrandingFooterLink": {
				"Hide": true
			},
			"BrandingAccentColor": {
				"Hide": true
			},
			"BrandingTextColor": {
				"Hide": true
			},
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
				"Select": {
					"Options": [
						{ "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
						{ "Display": "CSV only", "ParameterValue": "CSV only" },
						{ "Display": "XLSX only", "ParameterValue": "XLSX only" }
					],
					"ShowValue": false
				}
			},
			"CreateDownloadLink": {
				"Hide": true
			},
			"ContainerName": {
				"Hide": true
			},
			"ResourceGroupName": {
				"Hide": true
			},
			"StorageAccountName": {
				"Hide": true
			},
			"LinkExpiryDays": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "ExcludeDeviceGroup",
				"Select": {
					"Options": [
						{
							"Display": "Output Data only",
							"ParameterValue": "Output Data only",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Email report",
							"ParameterValue": "Email report",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Report download link",
							"ParameterValue": "Report download link",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Email report & download link",
							"ParameterValue": "Email report & download link",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				},
				"Default": "Output Data only"
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [int]$SyncThresholdDays = 30,
    [int]$AgentContactThresholdDays = 14,
    [string]$DeviceNamePrefix = "",
    [bool]$IncludeAgentStale = $true,
    [bool]$IncludeNeverSeen = $true,
    [bool]$IncludeMissingInRealmJoin = $false,
    [bool]$IncludeMissingInIntune = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include devices from group" } )]
    [string]$IncludeDeviceGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude devices from group" } )]
    [string]$ExcludeDeviceGroup,
    # Standard report-delivery parameter set (report-files mode)
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string]$BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string]$BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string]$BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string]$BrandingTextColor,
    [bool]$SendEmailReport = $false,
    [string]$EmailTo,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',
    [bool]$CreateDownloadLink = $false,
    [string]$ContainerName = "report-realmjoin-agent-contact",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string]$ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string]$StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,
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

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SyncThresholdDays: $SyncThresholdDays" -Verbose
Write-RjRbLog -Message "AgentContactThresholdDays: $AgentContactThresholdDays" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "IncludeAgentStale: $IncludeAgentStale" -Verbose
Write-RjRbLog -Message "IncludeNeverSeen: $IncludeNeverSeen" -Verbose
Write-RjRbLog -Message "IncludeMissingInRealmJoin: $IncludeMissingInRealmJoin" -Verbose
Write-RjRbLog -Message "IncludeMissingInIntune: $IncludeMissingInIntune" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "ExcludeDeviceGroup: $ExcludeDeviceGroup" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# A sender address is required before any mail can be sent
if (($SendEmailReport -or $EmailTo) -and -not $EmailFrom) {
    Write-Error "The sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)"
}

# Email delivery needs a recipient
if ($SendEmailReport -and -not $EmailTo) {
    Write-Error "Email delivery is selected but no recipient email address was provided." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

if ($SyncThresholdDays -le 0) {
    Write-Error "The Intune sync window must be at least 1 day. Received: '$SyncThresholdDays'." -ErrorAction Continue
    throw "SyncThresholdDays must be greater than 0"
}

if ($AgentContactThresholdDays -le 0) {
    Write-Error "The allowed gap to the RealmJoin last seen must be at least 1 day. Received: '$AgentContactThresholdDays'." -ErrorAction Continue
    throw "AgentContactThresholdDays must be greater than 0"
}

# Devices missing in Intune cannot be matched to a device name, so a name prefix and that category exclude each other
if ($IncludeMissingInIntune -and -not [string]::IsNullOrWhiteSpace($DeviceNamePrefix)) {
    Write-Output "Note: devices missing in Intune have no device name to match the prefix against. That category is skipped for this run."
    $IncludeMissingInIntune = $false
}

# The RealmJoin customer API is authenticated with the Automation Account credential 'RJAPI'.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
Write-RjRbLog -Message "Retrieving Automation Account credential 'RJAPI' for RealmJoin API authentication." -Verbose
$rjApiCredential = Get-AutomationPSCredential -Name "RJAPI"

if ($null -eq $rjApiCredential) {
    Write-Error @"
The Automation Account shared credential named 'RJAPI' is missing.
See the runbook documentation https://docs.realmjoin.com/automation/runbooks/runbook-references/org/devices/report-realmjoin-agent-contact_scheduled for the setup.

Step-by-step setup:
  1. If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
  2. In the Azure portal, open the Azure Automation Account used for runbooks
  3. Navigate to Shared Resources > Credentials
  4. Click 'Add a credential'
  5. Set the name to exactly: RJAPI
  6. Enter the RealmJoin API username (t-<tenant id>) and the API secret
  7. Save and re-run this runbook
"@ -ErrorAction Continue
    throw "Automation Account credential 'RJAPI' not found. Cannot authenticate to the RealmJoin API without it."
}

# The API username is the tenant id with a 't-' (or 'r-' for a red tenant) prefix. A portal login stored by mistake is the most common setup error.
if ("$($rjApiCredential.UserName)" -notmatch '^[tr]-') {
    Write-Output "WARNING: the username of the 'RJAPI' credential ('$($rjApiCredential.UserName)') does not look like a RealmJoin API username (t-<tenant id>). If the API call fails, check the credential."
}

Write-RjRbLog -Message "Credential 'RJAPI' retrieved. API username: '$($rjApiCredential.UserName)'." -Verbose
Write-Output "RealmJoin API credential 'RJAPI' - OK"
Write-Output "Parameter validation passed."

#endregion Parameter Validation

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

function Invoke-RjCustomerApiRequest {
    <#
        .SYNOPSIS
        Calls the RealmJoin customer API with Basic authentication and retries throttled requests.

        .DESCRIPTION
        The customer API allows 30 requests per minute per tenant and answers with HTTP 429 beyond that,
        without a Retry-After header. A throttled request is repeated after a growing delay up to
        MaxAttempts times. Every other error is passed on to the caller.

        .PARAMETER Uri
        Full URL of the API endpoint.

        .PARAMETER Headers
        Request headers including the Authorization header.

        .PARAMETER MaxAttempts
        Number of attempts before a throttled request is given up.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        [int]$MaxAttempts = 5
    )

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-RestMethod -Uri $Uri -Method GET -Headers $Headers -ErrorAction Stop
        }
        catch {
            $statusCode = Get-RjApiStatusCode -ErrorRecord $_
            if ($statusCode -eq 429 -and $attempt -lt $MaxAttempts) {
                $delaySeconds = 10 * $attempt
                try {
                    $retryAfter = $_.Exception.Response.Headers.RetryAfter
                    if ($retryAfter -and $retryAfter.Delta) {
                        $delaySeconds = [int][math]::Ceiling($retryAfter.Delta.TotalSeconds)
                    }
                }
                catch {
                    Write-RjRbLog -Message "Retry-After header could not be read, using the fallback delay." -Verbose
                }
                if ($delaySeconds -lt 1) { $delaySeconds = 1 }
                Write-RjRbLog -Message "The RealmJoin API throttled the request ($Uri). Retrying in $delaySeconds second(s), attempt $attempt of $MaxAttempts." -Verbose
                Start-Sleep -Seconds $delaySeconds
                continue
            }
            throw
        }
    }
}

function Get-RjApiStatusCode {
    <#
        .SYNOPSIS
        Returns the HTTP status code of a failed web request, or 0 when there is none.

        .PARAMETER ErrorRecord
        The error record thrown by Invoke-RestMethod.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if ($ErrorRecord.Exception.Response) {
        try { return [int]$ErrorRecord.Exception.Response.StatusCode } catch { return 0 }
    }
    return 0
}

function Get-RealmJoinLastSeen {
    <#
        .SYNOPSIS
        Returns the newest last-seen timestamp among the users of a RealmJoin device.

        .DESCRIPTION
        The RealmJoin customer API reports per device the users the agent has seen signed in, each with a
        lastSeen timestamp. RealmJoin writes the same server timestamp to the user and to the device with
        every agent report, so the newest of these timestamps is the device's last agent contact. A device
        without users has never reported a signed-in user.

        .PARAMETER RjDevice
        A device entry from the RealmJoin customer API (/device/list).
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RjDevice
    )

    $latest = $null
    $latestUser = ""
    foreach ($user in @($RjDevice.users)) {
        if ($null -eq $user -or -not $user.lastSeen) { continue }
        try {
            $seen = ([datetime]$user.lastSeen).ToUniversalTime()
        }
        catch {
            continue
        }
        if ($null -eq $latest -or $seen -gt $latest) {
            $latest = $seen
            $latestUser = "$($user.userName)"
        }
    }

    return [PSCustomObject]@{
        LastSeen = $latest
        UserName = $latestUser
    }
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name for the email subject, the email body and the report file names (needs Organization.Read.All)
Write-Output "Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
    Write-Output "Tenant: $tenantDisplayName"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Intune Managed Devices"
Write-Output "---------------------"

# Only Windows devices that synced within the window; the name prefix is applied client-side.
$thresholdDate = (Get-Date).AddDays(-$SyncThresholdDays)
$isoThresholdDate = $thresholdDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-RjRbLog -Message "Intune sync threshold date (UTC): $isoThresholdDate (last $SyncThresholdDays days)" -Verbose

$intuneFilter = "operatingSystem eq 'Windows' and lastSyncDateTime ge $isoThresholdDate"
$intuneUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$([uri]::EscapeDataString($intuneFilter))&`$select=id,deviceName,azureADDeviceId,userPrincipalName,operatingSystem,lastSyncDateTime"

try {
    $intuneDevices = @(Get-GraphPagedResult -Uri $intuneUri)
}
catch {
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve the Intune device inventory"
}

Write-Output "Retrieved $($intuneDevices.Count) Windows device(s) that synced with Intune in the last $SyncThresholdDays day(s)."
Write-RjRbLog -Message "Intune devices retrieved: $($intuneDevices.Count)" -Verbose

Write-Output ""
Write-Output "Get RealmJoin Devices"
Write-Output "---------------------"

# Basic authentication against the RealmJoin customer API with the 'RJAPI' credential.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
$rjApiBase = "https://customer-api.realmjoin.com"
$rjApiPassword = $rjApiCredential.GetNetworkCredential().Password
$rjAuthRaw = "$($rjApiCredential.UserName):$rjApiPassword"
$rjAuthHeader = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rjAuthRaw))
$rjHeaders = @{
    Authorization = $rjAuthHeader
    Accept        = "application/json"
}

try {
    $rjResponse = Invoke-RjCustomerApiRequest -Uri "$rjApiBase/device/list" -Headers $rjHeaders
}
catch {
    $statusCode = Get-RjApiStatusCode -ErrorRecord $_
    if ($statusCode -eq 401) {
        Write-Error "The RealmJoin API rejected the 'RJAPI' credential (HTTP 401). The username has to be the API username (t-<tenant id>) and the password the API secret issued by RealmJoin support." -ErrorAction Continue
    }
    elseif ($statusCode -eq 403) {
        Write-Error "The RealmJoin API refused access to the device list (HTTP 403). The device users feature of the customer API is not enabled for this tenant - ask RealmJoin support to enable it." -ErrorAction Continue
    }
    else {
        Write-Error "Failed to retrieve devices from the RealmJoin API ($rjApiBase/device/list): $($_.Exception.Message). Verify the 'RJAPI' credential and that the API is reachable." -ErrorAction Continue
    }
    throw "Unable to retrieve the RealmJoin device list"
}

# Normalize the response to a plain array (a bare array today; a { value: [...] } wrapper is tolerated).
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

# RealmJoin's own client statistics are a plausibility check for the numbers below; a failure here never stops the run.
$rjStats = $null
try {
    $rjStats = Invoke-RjCustomerApiRequest -Uri "$rjApiBase/tenant/stats" -Headers $rjHeaders
}
catch {
    Write-RjRbLog -Message "RealmJoin tenant statistics could not be read: $($_.Exception.Message)" -Verbose
}
if ($rjStats -and $rjStats.clients) {
    $rjActivityThreshold = if ($rjStats.activityThreshold) { ([datetime]$rjStats.activityThreshold).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") } else { "unknown" }
    Write-Output "RealmJoin counts $($rjStats.clients.activeCount) active of $($rjStats.clients.totalCount) clients (agent contact since $rjActivityThreshold UTC, a RealmJoin tenant setting)."
}

# Optional device scope by Entra group membership. Device members expose the Entra device ID as 'deviceId',
# which matches the Intune azureADDeviceId and the RealmJoin entraDeviceId.
$includeDeviceIds = @()
$excludeDeviceIds = @()

if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) {
    Write-Output ""
    Write-Output "Retrieving members of the include device group..."
    try {
        $includeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$IncludeDeviceGroup/members?`$select=id,deviceId,displayName")
        $includeDeviceIds = @($includeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { "$($_.deviceId)".ToLower() })
        Write-Output "Include device group contains $($includeDeviceIds.Count) device(s)."
    }
    catch {
        Write-Error "Failed to retrieve the members of the include device group: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the include device group membership"
    }
}

if (-not [string]::IsNullOrEmpty($ExcludeDeviceGroup)) {
    Write-Output ""
    Write-Output "Retrieving members of the exclude device group..."
    try {
        $excludeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeDeviceGroup/members?`$select=id,deviceId,displayName")
        $excludeDeviceIds = @($excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { "$($_.deviceId)".ToLower() })
        Write-Output "Exclude device group contains $($excludeDeviceIds.Count) device(s)."
    }
    catch {
        Write-Error "Failed to retrieve the members of the exclude device group: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the exclude device group membership"
    }
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Comparing Intune sync and RealmJoin last seen"
Write-Output "---------------------"

# Lookups of the RealmJoin devices by Entra device id (primary) and Intune device id (fallback), lowercased.
$rjDevicesByEntraId = @{}
$rjDevicesByIntuneId = @{}
foreach ($rjDevice in $rjDevices) {
    if (-not [string]::IsNullOrEmpty($rjDevice.entraDeviceId)) {
        $rjDevicesByEntraId["$($rjDevice.entraDeviceId)".ToLower()] = $rjDevice
    }
    if (-not [string]::IsNullOrEmpty($rjDevice.intuneDeviceId)) {
        $rjDevicesByIntuneId["$($rjDevice.intuneDeviceId)".ToLower()] = $rjDevice
    }
}

# Device name prefix (client-side, case-insensitive)
$filteredIntuneDevices = if ([string]::IsNullOrWhiteSpace($DeviceNamePrefix)) {
    $intuneDevices
}
else {
    @($intuneDevices | Where-Object { "$($_.deviceName)" -like "$DeviceNamePrefix*" })
}
Write-RjRbLog -Message "Intune devices after the name prefix filter: $($filteredIntuneDevices.Count)" -Verbose

$reportData = [System.Collections.Generic.List[object]]::new()

foreach ($intuneDevice in $filteredIntuneDevices) {
    $rjDevice = $null
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) {
        $rjDevice = $rjDevicesByEntraId["$($intuneDevice.azureADDeviceId)".ToLower()]
    }
    if (-not $rjDevice -and -not [string]::IsNullOrEmpty($intuneDevice.id)) {
        $rjDevice = $rjDevicesByIntuneId["$($intuneDevice.id)".ToLower()]
    }

    $intuneSync = $null
    if ($intuneDevice.lastSyncDateTime) {
        $intuneSync = ([datetime]$intuneDevice.lastSyncDateTime).ToUniversalTime()
    }
    $primaryUser = if ([string]::IsNullOrEmpty($intuneDevice.userPrincipalName)) { "(none)" } else { "$($intuneDevice.userPrincipalName)" }

    $rjLastSeen = $null
    $rjLastSeenUser = ""
    $gapDays = $null
    if ($rjDevice) {
        $seen = Get-RealmJoinLastSeen -RjDevice $rjDevice
        $rjLastSeen = $seen.LastSeen
        $rjLastSeenUser = $seen.UserName
    }

    # The gap is how long Intune kept seeing the device after RealmJoin last did. A gap at or above the
    # threshold means the device was in use while the agent did not report: the agent is stale.
    if (-not $rjDevice) {
        $status = "MissingInRealmJoin"
    }
    elseif ($null -eq $rjLastSeen) {
        $status = "NeverSeen"
    }
    else {
        $gapDays = if ($intuneSync) { [math]::Round(($intuneSync - $rjLastSeen).TotalDays, 1) } else { 0 }
        $status = if ($gapDays -ge $AgentContactThresholdDays) { "AgentStale" } else { "InSync" }
    }

    $reportData.Add([PSCustomObject]@{
            DeviceName            = "$($intuneDevice.deviceName)"
            AzureAdDeviceId       = "$($intuneDevice.azureADDeviceId)"
            IntuneDeviceId        = "$($intuneDevice.id)"
            PrimaryUser           = $primaryUser
            IntuneLastSync        = if ($intuneSync) { $intuneSync.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            RealmJoinLastSeen     = if ($rjLastSeen) { $rjLastSeen.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            RealmJoinLastSeenUser = if ($rjLastSeenUser) { $rjLastSeenUser } else { "(none)" }
            GapDays               = if ($null -ne $gapDays) { $gapDays } else { "" }
            Status                = $status
        })
}

# RealmJoin devices without an Intune counterpart in the sync window. Matched against the unfiltered Intune
# list, because the name prefix cannot be applied to RealmJoin devices (the API carries no device name).
if ($IncludeMissingInIntune) {
    $intuneEntraIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $intuneIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($intuneDevice in $intuneDevices) {
        if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) { [void]$intuneEntraIds.Add("$($intuneDevice.azureADDeviceId)") }
        if (-not [string]::IsNullOrEmpty($intuneDevice.id)) { [void]$intuneIds.Add("$($intuneDevice.id)") }
    }
    foreach ($rjDevice in $rjDevices) {
        $entraId = "$($rjDevice.entraDeviceId)"
        $intuneId = "$($rjDevice.intuneDeviceId)"
        if ($entraId -and $intuneEntraIds.Contains($entraId)) { continue }
        if ($intuneId -and $intuneIds.Contains($intuneId)) { continue }
        $seen = Get-RealmJoinLastSeen -RjDevice $rjDevice
        $reportData.Add([PSCustomObject]@{
                DeviceName            = "N/A"
                AzureAdDeviceId       = $entraId
                IntuneDeviceId        = $intuneId
                PrimaryUser           = "(none)"
                IntuneLastSync        = "N/A"
                RealmJoinLastSeen     = if ($seen.LastSeen) { $seen.LastSeen.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
                RealmJoinLastSeenUser = if ($seen.UserName) { $seen.UserName } else { "(none)" }
                GapDays               = ""
                Status                = "MissingInIntune"
            })
    }
}

# Device scope by group membership, applied after the full set is assembled so the counts reflect the scope.
if (($includeDeviceIds.Count -gt 0) -or ($excludeDeviceIds.Count -gt 0)) {
    $beforeScopeCount = $reportData.Count
    $scoped = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $reportData) {
        $deviceEntraId = if (-not [string]::IsNullOrEmpty($row.AzureAdDeviceId)) { $row.AzureAdDeviceId.ToLower() } else { $null }
        if (($includeDeviceIds.Count -gt 0) -and (($null -eq $deviceEntraId) -or ($deviceEntraId -notin $includeDeviceIds))) { continue }
        if (($excludeDeviceIds.Count -gt 0) -and ($null -ne $deviceEntraId) -and ($deviceEntraId -in $excludeDeviceIds)) { continue }
        $scoped.Add($row)
    }
    $reportData = $scoped
    Write-Output "Device scope applied: $beforeScopeCount device(s) reduced to $($reportData.Count)."
}

# Categories the run reports on
$includedStatuses = [System.Collections.Generic.List[string]]::new()
if ($IncludeAgentStale) { $includedStatuses.Add("AgentStale") }
if ($IncludeNeverSeen) { $includedStatuses.Add("NeverSeen") }
if ($IncludeMissingInRealmJoin) { $includedStatuses.Add("MissingInRealmJoin") }
if ($IncludeMissingInIntune) { $includedStatuses.Add("MissingInIntune") }
if ($includedStatuses.Count -eq 0) {
    Write-Output "WARNING: no category is selected, the report will contain no devices."
}
Write-RjRbLog -Message "Included statuses: $($includedStatuses -join ', ')" -Verbose

$results = @($reportData | Where-Object { $includedStatuses -contains $_.Status } | Sort-Object Status, DeviceName)

$totalEvaluated = @($reportData | Where-Object { $_.Status -ne "MissingInIntune" }).Count
$inSyncCount = @($reportData | Where-Object { $_.Status -eq "InSync" }).Count
$agentStaleCount = @($reportData | Where-Object { $_.Status -eq "AgentStale" }).Count
$neverSeenCount = @($reportData | Where-Object { $_.Status -eq "NeverSeen" }).Count
$missingInRjCount = @($reportData | Where-Object { $_.Status -eq "MissingInRealmJoin" }).Count
$missingInIntuneCount = @($reportData | Where-Object { $_.Status -eq "MissingInIntune" }).Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Intune devices evaluated: $totalEvaluated"
Write-Output "In sync: $inSyncCount"
Write-Output "Agent stale (gap of $AgentContactThresholdDays days or more): $agentStaleCount"
Write-Output "Never seen by RealmJoin: $neverSeenCount"
Write-Output "Missing in RealmJoin: $missingInRjCount"
if ($IncludeMissingInIntune) {
    Write-Output "Missing in Intune: $missingInIntuneCount"
}
Write-Output "Devices in the report: $($results.Count)"
Write-RjRbLog -Message "Evaluated: $totalEvaluated; InSync: $inSyncCount; AgentStale: $agentStaleCount; NeverSeen: $neverSeenCount; MissingInRealmJoin: $missingInRjCount; MissingInIntune: $missingInIntuneCount" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFile = $null
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "RealmJoinAgentContact_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "RealmJoinAgentContact_$($safeTenantName)_$(Get-Date -Format 'yyyyMMdd')"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($SendEmailReport -or $CreateDownloadLink) -and $results.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFile = Join-Path $tempDir "$fileNameBase.csv"
        $results | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFile
        Write-RjRbLog -Message "Exported $($results.Count) row(s) to CSV: $csvFile" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFile = Join-Path $tempDir "$fileNameBase.xlsx"
        $workbookCoverSheet = [ordered]@{
            Title                          = 'RealmJoin Agent Contact'
            Tenant                         = $tenantDisplayName
            Generated                      = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'              = $Version
            'Intune sync window (days)'    = $SyncThresholdDays
            'Allowed gap (days)'           = $AgentContactThresholdDays
            'Intune devices evaluated'     = $totalEvaluated
            'Agent stale'                  = $agentStaleCount
            'Never seen by RealmJoin'      = $neverSeenCount
            'Missing in RealmJoin'         = $missingInRjCount
            'Missing in Intune'            = $missingInIntuneCount
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Devices' = $results }) -Path $xlsxFile -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $($results.Count) row(s) to XLSX: $xlsxFile" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($results.Count -eq 0) {
    Write-RjRbLog -Message "No devices in the report - skipping the report file export" -Verbose
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "## Uploading the report file(s) to the storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        try {
            $uploadResults = Publish-RjRbFilesToStorageContainer `
                -FilePaths $reportFiles `
                -ContainerName $ContainerName `
                -ResourceGroupName $ResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -LinkExpiryDays $LinkExpiryDays `
                -AddBlobNamePrefix $true
        }
        catch {
            Write-Error "Failed to upload the report file(s) to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Storage Account Contributor' role on the storage account." -ErrorAction Continue
            throw
        }

        foreach ($uploadResult in $uploadResults) {
            Write-Output ""
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No devices in the report - skipping the upload."
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

if ($SendEmailReport -and $EmailTo) {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    $emailSubject = "RealmJoin Agent Contact Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $previewRows = @($results | Select-Object -First 10)
    $previewTable = if ($previewRows.Count -gt 0) {
        $tableLines = @("| Device | Primary user | Intune last sync | RealmJoin last seen | Gap (days) | Status |", "|---|---|---|---|---|---|")
        foreach ($row in $previewRows) {
            $tableLines += "| $($row.DeviceName) | $($row.PrimaryUser) | $($row.IntuneLastSync) | $($row.RealmJoinLastSeen) | $($row.GapDays) | $($row.Status) |"
        }
        $tableLines -join "`n"
    }
    else {
        "No devices matched the selected categories - the RealmJoin agent reports on every evaluated device."
    }
    $xlsxFileName = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { "the Excel workbook" }

    $rjStatsLine = if ($rjStats -and $rjStats.clients) { "| **RealmJoin active clients (RealmJoin count)** | $($rjStats.clients.activeCount) of $($rjStats.clients.totalCount) |" } else { "" }

    $summaryTable = @"
| Metric | Count |
|--------|-------|
| **Intune devices evaluated** | $totalEvaluated |
| **In sync** | $inSyncCount |
| **Agent stale (gap of $AgentContactThresholdDays days or more)** | $agentStaleCount |
| **Never seen by RealmJoin** | $neverSeenCount |
| **Missing in RealmJoin** | $missingInRjCount |
| **Missing in Intune** | $missingInIntuneCount |
$rjStatsLine
"@

    $markdownContent = @"
# RealmJoin Agent Contact Report

Tenant: **$tenantDisplayName**

Windows devices that synced with Intune in the last $SyncThresholdDays day(s), compared with the last time the RealmJoin agent reported a signed-in user on them.

## Summary

$summaryTable

## Preview (first $($previewRows.Count) of $($results.Count))

$previewTable

## Attachments

The attached report file(s) contain the full data set.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Body used when only the workbook can be attached because the CSV exceeds the attachment size limit
    $markdownFallback = @"
# RealmJoin Agent Contact Report

Tenant: **$tenantDisplayName**

## Summary

$summaryTable

## Attachments

- **$xlsxFileName**: Excel workbook with the complete data set

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. Select the download link option to obtain the CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $emailParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $emailSubject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true
        }

        if ($reportFiles.Count -eq 0) {
            # No devices, no files - still send the report so the recipient knows the run happened
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the pair is too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }

        Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
        Write-Output "Email report sent to '$EmailTo'."
    }
    catch {
        Write-Error "Failed to send the email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}
else {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
$maxTableRows = 250
Write-Output ""

$summaryValues = [ordered]@{
    "Intune devices evaluated"                              = $totalEvaluated
    "In sync"                                               = $inSyncCount
    "Agent stale (gap of $AgentContactThresholdDays days or more)" = $agentStaleCount
    "Never seen by RealmJoin"                               = $neverSeenCount
    "Missing in RealmJoin"                                  = $missingInRjCount
    "Missing in Intune"                                     = $missingInIntuneCount
}
if ($rjStats -and $rjStats.clients) {
    $summaryValues["RealmJoin active clients (RealmJoin count)"] = [int]$rjStats.clients.activeCount
    $summaryValues["RealmJoin clients total (RealmJoin count)"] = [int]$rjStats.clients.totalCount
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

$agentStaleRows = @($results | Where-Object { $_.Status -eq "AgentStale" } | Select-Object -First $maxTableRows -Property DeviceName, PrimaryUser, IntuneLastSync, RealmJoinLastSeen, RealmJoinLastSeenUser, GapDays)
if ($agentStaleRows.Count -gt 0) {
    Write-Output "$agentStaleCount device(s) with a stale RealmJoin agent$(if ($agentStaleCount -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Agent stale" })
    Write-Output $agentStaleRows
}
elseif ($IncludeAgentStale) {
    Write-Output "No devices with a stale RealmJoin agent."
}

$neverSeenRows = @($results | Where-Object { $_.Status -eq "NeverSeen" } | Select-Object -First $maxTableRows -Property DeviceName, PrimaryUser, IntuneLastSync)
if ($neverSeenRows.Count -gt 0) {
    Write-Output "$neverSeenCount device(s) never seen by RealmJoin$(if ($neverSeenCount -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Never seen by RealmJoin" })
    Write-Output $neverSeenRows
}
elseif ($IncludeNeverSeen) {
    Write-Output "No devices that RealmJoin has never seen."
}

$missingInRjRows = @($results | Where-Object { $_.Status -eq "MissingInRealmJoin" } | Select-Object -First $maxTableRows -Property DeviceName, PrimaryUser, IntuneLastSync)
if ($missingInRjRows.Count -gt 0) {
    Write-Output "$missingInRjCount device(s) missing in RealmJoin$(if ($missingInRjCount -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Missing in RealmJoin" })
    Write-Output $missingInRjRows
}
elseif ($IncludeMissingInRealmJoin) {
    Write-Output "No devices missing in RealmJoin."
}

$missingInIntuneRows = @($results | Where-Object { $_.Status -eq "MissingInIntune" } | Select-Object -First $maxTableRows -Property AzureAdDeviceId, IntuneDeviceId, RealmJoinLastSeen, RealmJoinLastSeenUser)
if ($missingInIntuneRows.Count -gt 0) {
    Write-Output "$missingInIntuneCount device(s) missing in Intune$(if ($missingInIntuneCount -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Missing in Intune" })
    Write-Output $missingInIntuneRows
}
elseif ($IncludeMissingInIntune) {
    Write-Output "No devices missing in Intune."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

# Remove the temporary report files, if any were created
foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
        }
        catch {
            Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
        }
    }
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove the downloaded branding images, if any were used
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
