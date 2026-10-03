<#
	.SYNOPSIS
	Compare primary users and logons between Intune and RealmJoin

	.DESCRIPTION
	Compares, for Windows devices, the primary user recorded in Intune with the one recorded in RealmJoin and lists every device where they differ. It also checks who actually logs on to each device, using the logons Intune and the RealmJoin agent recorded, and lists devices whose primary user no longer does. Which categories are listed is set in the runbook customization. Only devices that synced with Intune recently are considered. The report can be sent by email or provided as a download link.

	.PARAMETER SyncThresholdDays
	Only devices that synced with Intune within this many days are compared. Devices that stopped syncing altogether belong in the stale device report instead.

	.PARAMETER DeviceNamePrefix
	Only devices whose name starts with this text. Leave empty for all.

	.PARAMETER PrimaryUserLogonDays
	The primary user counts as not logging on when someone else logged on to the device and the primary user did not within this many days.

	.PARAMETER IncludeMismatches
	Lists devices whose primary user differs between Intune and RealmJoin.

	.PARAMETER IncludeMissingInRealmJoin
	Lists devices that exist in Intune but not in RealmJoin, or that RealmJoin knows without a primary user.

	.PARAMETER IncludeMissingInIntune
	Lists devices that exist in RealmJoin but did not sync with Intune within the sync window.

	.PARAMETER IncludePrimaryUserDeleted
	Lists devices whose Intune primary user was deleted from Entra ID. Without this they would look like mismatches, because Intune rewrites the name of a deleted user.

	.PARAMETER IncludePrimaryUserNotLoggingOn
	Lists devices where other users log on but the primary user has not within "Primary user must have logged on within (days)". Uses the logons Intune and the RealmJoin agent recorded.

	.PARAMETER IncludeDeviceGroup
	Only devices in this Entra ID group. Leave empty for all devices.

	.PARAMETER ExcludeDeviceGroup
	Skips devices in this Entra ID group, for example shared devices where several people log on by design. Leave empty to skip none.

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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
			"DeviceNamePrefix": {
				"DisplayName": "Device name prefix"
			},
			"PrimaryUserLogonDays": {
				"DisplayName": "Primary user must have logged on within (days)"
			},
			"IncludeMismatches": {
				"DisplayName": "Include mismatches?",
				"Hide": true
			},
			"IncludeMissingInRealmJoin": {
				"DisplayName": "Include devices missing in RealmJoin?",
				"Hide": true
			},
			"IncludeMissingInIntune": {
				"DisplayName": "Include devices missing in Intune?",
				"Hide": true
			},
			"IncludePrimaryUserDeleted": {
				"DisplayName": "Include deleted primary users?",
				"Hide": true
			},
			"IncludePrimaryUserNotLoggingOn": {
				"DisplayName": "Include primary users not logging on?",
				"Hide": true
			},
			"IncludeDeviceGroup": {
				"DisplayName": "Include devices from group"
			},
			"ExcludeDeviceGroup": {
				"DisplayName": "Exclude devices from group"
			},
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
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
			"EmailFrom": {
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
							"Display": "Also email the report",
							"ParameterValue": "Also email the report",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also create a download link",
							"ParameterValue": "Also create a download link",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also email & download link",
							"ParameterValue": "Also email & download link",
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

param (
    [int]$SyncThresholdDays = 30,

    [string]$DeviceNamePrefix = "",

    [int]$PrimaryUserLogonDays = 30,

    [bool]$IncludeMismatches = $true,

    [bool]$IncludeMissingInRealmJoin = $false,

    [bool]$IncludeMissingInIntune = $false,

    [bool]$IncludePrimaryUserDeleted = $false,

    [bool]$IncludePrimaryUserNotLoggingOn = $false,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include devices from group" } )]
    [string]$IncludeDeviceGroup,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude devices from group" } )]
    [string]$ExcludeDeviceGroup,

    [bool]$SendEmailReport = $false,

    [string]$EmailTo,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" })]
    [string]$EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" })]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" })]
    [string]$BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" })]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string]$BrandingTextColor,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-primary-user-mismatch",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" })]
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

$Version = "1.8.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SyncThresholdDays: $SyncThresholdDays" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "PrimaryUserLogonDays: $PrimaryUserLogonDays" -Verbose
Write-RjRbLog -Message "IncludeMismatches: $IncludeMismatches" -Verbose
Write-RjRbLog -Message "IncludeMissingInRealmJoin: $IncludeMissingInRealmJoin" -Verbose
Write-RjRbLog -Message "IncludeMissingInIntune: $IncludeMissingInIntune" -Verbose
Write-RjRbLog -Message "IncludePrimaryUserDeleted: $IncludePrimaryUserDeleted" -Verbose
Write-RjRbLog -Message "IncludePrimaryUserNotLoggingOn: $IncludePrimaryUserNotLoggingOn" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "ExcludeDeviceGroup: $ExcludeDeviceGroup" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# Schedules created before the "Report delivery" choice existed pass a recipient but no SendEmailReport.
# For them the recipient alone keeps the email enabled; every newer run passes SendEmailReport explicitly.
$sendEmail = if ($PSBoundParameters.ContainsKey('SendEmailReport')) { $SendEmailReport } else { [bool]$EmailTo }

# Email delivery needs a recipient
if ($sendEmail -and -not $EmailTo) {
    Write-Error "Email delivery is selected but no recipient email address was provided." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)"
}

# A configured sender address is required before any mail can be sent
if ($sendEmail -and -not $EmailFrom) {
    Write-Error "The sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) or pass ResourceGroupName and StorageAccountName when starting the runbook." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

if ($SyncThresholdDays -le 0) {
    Write-Error "The Intune sync window must be at least 1 day. Received: '$SyncThresholdDays'." -ErrorAction Continue
    throw "SyncThresholdDays must be greater than 0"
}

if ($PrimaryUserLogonDays -le 0) {
    Write-Error "The logon window for the primary user must be at least 1 day. Received: '$PrimaryUserLogonDays'." -ErrorAction Continue
    throw "PrimaryUserLogonDays must be greater than 0"
}

# The RealmJoin customer API is authenticated with the Automation Account credential 'RJAPI'.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
Write-RjRbLog -Message "Retrieving Automation Account credential 'RJAPI' for RealmJoin API authentication." -Verbose
$rjApiCredential = Get-AutomationPSCredential -Name "RJAPI"

if ($null -eq $rjApiCredential) {
    Write-Error @"
The Automation Account shared credential named 'RJAPI' is missing.
See the runbook documentation https://docs.realmjoin.com/automation/runbooks/runbook-references/org/devices/report-primary-user-mismatch_scheduled for the setup.

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

$includedCategories = [System.Collections.Generic.List[string]]::new()
if ($IncludeMismatches) { $includedCategories.Add("Mismatch") }
if ($IncludePrimaryUserDeleted) { $includedCategories.Add("PrimaryUserDeleted") }
if ($IncludePrimaryUserNotLoggingOn) { $includedCategories.Add("PrimaryUserNotLoggingOn") }
if ($IncludeMissingInRealmJoin) { $includedCategories.Add("MissingInRealmJoin") }
if ($IncludeMissingInIntune) { $includedCategories.Add("MissingInIntune") }

if ($includedCategories.Count -eq 0) {
    Write-Output "WARNING: no category is enabled in the runbook customization - the report will contain no devices."
}
Write-Output "Categories in the report: $(if ($includedCategories.Count -gt 0) { $includedCategories -join ', ' } else { '(none)' })"
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

function ConvertTo-UtcDateTime {
    <#
        .SYNOPSIS
        Converts a timestamp from Graph or the RealmJoin API to a UTC datetime, or returns null.

        .PARAMETER Value
        The raw timestamp value.
    #>
    param(
        $Value
    )

    if ($null -eq $Value -or "$Value" -eq "") { return $null }
    try {
        return ([datetime]$Value).ToUniversalTime()
    }
    catch {
        return $null
    }
}

function Format-ReportDateTime {
    <#
        .SYNOPSIS
        Formats a UTC datetime for the report, or returns the given fallback text.

        .PARAMETER Value
        The datetime to format.

        .PARAMETER Fallback
        The text used when the value is empty.
    #>
    param(
        $Value,
        [string]$Fallback = "Never"
    )

    if ($null -eq $Value) { return $Fallback }
    return $Value.ToString("yyyy-MM-dd HH:mm:ss")
}

function Resolve-UserName {
    <#
        .SYNOPSIS
        Returns the user principal name for a user object id from the names collected during the run.

        .PARAMETER UserId
        The Entra ID object id of the user.
    #>
    param(
        [string]$UserId
    )

    if (-not $UserId) { return "(none)" }
    $key = $UserId.ToLower()
    if ($script:userNamesById.ContainsKey($key)) { return $script:userNamesById[$key] }
    return $UserId
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
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name for the email subject, the email body and the report file names (needs Organization.Read.All)
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

# Windows devices that synced within the window. The beta endpoint is needed for usersLoggedOn, the
# logons Intune recorded on the device. The name prefix is applied client-side in Data Processing.
$thresholdDate = (Get-Date).AddDays(-$SyncThresholdDays)
$isoThresholdDate = $thresholdDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-RjRbLog -Message "Intune sync threshold date (UTC): $isoThresholdDate (last $SyncThresholdDays days)" -Verbose

$intuneFilter = "operatingSystem eq 'Windows' and lastSyncDateTime ge $isoThresholdDate"
$intuneUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$([uri]::EscapeDataString($intuneFilter))&`$select=id,deviceName,azureADDeviceId,userId,userPrincipalName,operatingSystem,lastSyncDateTime,usersLoggedOn"

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

# Optional device scope by Entra group membership. Device members expose the Entra device ID as 'deviceId',
# which matches the Intune azureADDeviceId and the RealmJoin entraDeviceId.
$includeDeviceIds = @()
$excludeDeviceIds = @()

if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup) -or -not [string]::IsNullOrEmpty($ExcludeDeviceGroup)) {
    Write-Output ""
    Write-Output "Get Device Scope Groups"
    Write-Output "---------------------"
}

if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) {
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

Write-Output ""
Write-Output "Resolve Logged-on Users"
Write-Output "---------------------"

# Intune reports the logons on a device as user object ids only. The ids are resolved to user principal
# names in one batch; ids already known from the devices or from RealmJoin are not looked up again.
$script:userNamesById = @{}
foreach ($intuneDevice in $intuneDevices) {
    if ($intuneDevice.userId -and $intuneDevice.userPrincipalName) {
        # A deleted primary user carries its object id in front of the UPN; keep the readable part and mark it.
        $name = "$($intuneDevice.userPrincipalName)"
        if ($name -match '^[0-9a-fA-F]{32}(?<upn>.+@.+)$') { $name = "$($Matches['upn']) (deleted)" }
        $script:userNamesById["$($intuneDevice.userId)".ToLower()] = $name
    }
}
foreach ($rjDevice in $rjDevices) {
    foreach ($rjUser in @($rjDevice.users)) {
        if ($rjUser -and $rjUser.entraId -and $rjUser.userName) {
            $key = "$($rjUser.entraId)".ToLower()
            if (-not $script:userNamesById.ContainsKey($key)) { $script:userNamesById[$key] = "$($rjUser.userName)" }
        }
    }
}

$unknownUserIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($intuneDevice in $intuneDevices) {
    foreach ($logon in @($intuneDevice.usersLoggedOn)) {
        if ($logon -and $logon.userId) {
            $key = "$($logon.userId)".ToLower()
            if (-not $script:userNamesById.ContainsKey($key)) { [void]$unknownUserIds.Add($key) }
        }
    }
}

if ($unknownUserIds.Count -gt 0) {
    Write-Output "Looking up $($unknownUserIds.Count) user(s) from the Intune logon records..."
    $lookupRequests = foreach ($userId in $unknownUserIds) {
        @{
            id     = $userId
            method = "GET"
            url    = "/users/$userId`?`$select=id,userPrincipalName"
        }
    }
    try {
        $lookupResponses = @(Invoke-RjRbGraphBatch -Requests @($lookupRequests) -ProgressLabel "user lookups" -ProgressInterval 10)
        foreach ($response in $lookupResponses) {
            $key = "$($response.id)".ToLower()
            if ($response.status -eq 200 -and $response.body.userPrincipalName) {
                $script:userNamesById[$key] = "$($response.body.userPrincipalName)"
            }
            elseif ($response.status -eq 404) {
                # The account no longer exists; the logon record stays, so the row shows it as deleted.
                $script:userNamesById[$key] = "$key (deleted)"
            }
            else {
                Write-RjRbLog -Message "User lookup for '$key' failed with status $($response.status)." -Verbose
            }
        }
    }
    catch {
        # Unresolved ids are shown as ids; the comparison itself works on ids and is not affected.
        Write-RjRbLog -Message "Batch lookup of the logged-on users failed: $($_.Exception.Message)" -Verbose
        Write-Output "WARNING: the logged-on users could not all be resolved to names; unresolved users are shown by their id."
    }
}
else {
    Write-Output "All logged-on users are already known by name."
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Comparing Intune and RealmJoin"
Write-Output "---------------------"

$nowUtc = (Get-Date).ToUniversalTime()
$logonWindowStart = $nowUtc.AddDays(-$PrimaryUserLogonDays)

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
    # Detect a deleted Entra primary user: Intune then prefixes the user's object id (32 hex chars, no
    # dashes) to the original UPN, e.g. "702fabaa7fef412ea14ed0bea71e8729heidi.kabel@contoso.com".
    $intunePrimaryUserDeleted = $false
    $intunePrimaryUser = if ([string]::IsNullOrEmpty($intuneDevice.userPrincipalName)) { "(none)" } else { "$($intuneDevice.userPrincipalName)" }
    if ($intuneDevice.userPrincipalName -match '^[0-9a-fA-F]{32}(?<upn>.+@.+)$') {
        $intunePrimaryUserDeleted = $true
        $intunePrimaryUser = $Matches['upn']
    }
    $intunePrimaryUserId = if ($intuneDevice.userId) { "$($intuneDevice.userId)".ToLower() } else { "" }

    # Match against RealmJoin by Entra device id first, then by Intune device id.
    $rjDevice = $null
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) {
        $rjDevice = $rjDevicesByEntraId["$($intuneDevice.azureADDeviceId)".ToLower()]
    }
    if (-not $rjDevice -and -not [string]::IsNullOrEmpty($intuneDevice.id)) {
        $rjDevice = $rjDevicesByIntuneId["$($intuneDevice.id)".ToLower()]
    }

    $rjUsers = if ($rjDevice) { @($rjDevice.users | Where-Object { $null -ne $_ }) } else { @() }
    $rjPrimaryUser = $rjUsers | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { "$($rjPrimaryUser.userName)" } else { "(none)" }

    # Primary user comparison. A deleted Intune primary user takes precedence: it is a cleanup candidate,
    # not a configuration drift. A device absent from RealmJoin, or present without a primary user, is
    # MissingInRealmJoin.
    if ($intunePrimaryUserDeleted) {
        $status = "PrimaryUserDeleted"
    }
    elseif ($rjPrimaryUser -and $rjPrimaryUserName -ne "(none)") {
        $status = if ($intunePrimaryUser.ToLower() -eq $rjPrimaryUserName.ToLower()) { "Match" } else { "Mismatch" }
    }
    else {
        $status = "MissingInRealmJoin"
    }

    # Logons: Intune's usersLoggedOn (object ids with a timestamp) and the users the RealmJoin agent saw
    # signed in, each with its lastSeen. The newest logon of the primary user and the newest logon of
    # anyone else decide whether the primary user still uses the device.
    $intuneLastLogon = $null
    $intuneLastLogonUserId = ""
    $primaryLastLogon = $null
    $otherLastLogon = $null
    $otherLastLogonUser = ""
    foreach ($logon in @($intuneDevice.usersLoggedOn)) {
        if (-not $logon -or -not $logon.userId) { continue }
        $logonTime = ConvertTo-UtcDateTime -Value $logon.lastLogOnDateTime
        if ($null -eq $logonTime) { continue }
        $logonUserId = "$($logon.userId)".ToLower()
        if ($null -eq $intuneLastLogon -or $logonTime -gt $intuneLastLogon) {
            $intuneLastLogon = $logonTime
            $intuneLastLogonUserId = $logonUserId
        }
        if ($intunePrimaryUserId -and $logonUserId -eq $intunePrimaryUserId) {
            if ($null -eq $primaryLastLogon -or $logonTime -gt $primaryLastLogon) { $primaryLastLogon = $logonTime }
        }
        elseif ($null -eq $otherLastLogon -or $logonTime -gt $otherLastLogon) {
            $otherLastLogon = $logonTime
            $otherLastLogonUser = Resolve-UserName -UserId $logonUserId
        }
    }
    $rjLastSeen = $null
    $rjLastSeenUser = ""
    foreach ($rjUser in $rjUsers) {
        $seen = ConvertTo-UtcDateTime -Value $rjUser.lastSeen
        if ($null -eq $seen) { continue }
        if ($null -eq $rjLastSeen -or $seen -gt $rjLastSeen) {
            $rjLastSeen = $seen
            $rjLastSeenUser = "$($rjUser.userName)"
        }
        $rjUserId = "$($rjUser.entraId)".ToLower()
        if ($intunePrimaryUserId -and $rjUserId -eq $intunePrimaryUserId) {
            if ($null -eq $primaryLastLogon -or $seen -gt $primaryLastLogon) { $primaryLastLogon = $seen }
        }
        elseif ($null -eq $otherLastLogon -or $seen -gt $otherLastLogon) {
            $otherLastLogon = $seen
            $otherLastLogonUser = "$($rjUser.userName)"
        }
    }
    $intuneLastLogonUser = if ($intuneLastLogonUserId) { Resolve-UserName -UserId $intuneLastLogonUserId } else { "(none)" }

    if ($intunePrimaryUser -eq "(none)" -or $intunePrimaryUserDeleted) {
        $primaryUserLogon = "N/A"
    }
    elseif ($null -eq $otherLastLogon -and $null -eq $primaryLastLogon) {
        $primaryUserLogon = "Unknown"
    }
    elseif ($null -ne $otherLastLogon -and ($null -eq $primaryLastLogon -or $primaryLastLogon -lt $logonWindowStart)) {
        $primaryUserLogon = "NotLoggingOn"
    }
    else {
        $primaryUserLogon = "LoggingOn"
    }

    # Every applicable category, independent of the Include switches; the switches select the rows below.
    $findings = [System.Collections.Generic.List[string]]::new()
    if ($status -in @("Mismatch", "PrimaryUserDeleted", "MissingInRealmJoin")) { $findings.Add($status) }
    if ($primaryUserLogon -eq "NotLoggingOn") { $findings.Add("PrimaryUserNotLoggingOn") }

    $reportData.Add([PSCustomObject]@{
            DeviceName            = "$($intuneDevice.deviceName)"
            AzureAdDeviceId       = "$($intuneDevice.azureADDeviceId)"
            IntuneDeviceId        = "$($intuneDevice.id)"
            IntunePrimaryUser     = $intunePrimaryUser
            RealmJoinPrimaryUser  = $rjPrimaryUserName
            Status                = $status
            IntuneLastLogonUser   = $intuneLastLogonUser
            IntuneLastLogon       = Format-ReportDateTime -Value $intuneLastLogon
            RealmJoinLastSeenUser = if ($rjLastSeenUser) { $rjLastSeenUser } else { "(none)" }
            RealmJoinLastSeen     = Format-ReportDateTime -Value $rjLastSeen
            PrimaryUserLastLogon  = Format-ReportDateTime -Value $primaryLastLogon
            OtherUserLastLogon    = if ($otherLastLogonUser) { "$otherLastLogonUser ($(Format-ReportDateTime -Value $otherLastLogon))" } else { "(none)" }
            PrimaryUserLogon      = $primaryUserLogon
            IntuneLastSync        = Format-ReportDateTime -Value (ConvertTo-UtcDateTime -Value $intuneDevice.lastSyncDateTime)
            Findings              = ($findings -join ", ")
        })
}

# RealmJoin devices without an Intune counterpart in the sync window (in scope after the name filter).
$intuneEntraIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($intuneDevice in $filteredIntuneDevices) {
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) { [void]$intuneEntraIds.Add("$($intuneDevice.azureADDeviceId)") }
}
foreach ($rjDevice in $rjDevices) {
    $entraId = "$($rjDevice.entraDeviceId)"
    if (-not $entraId -or $intuneEntraIds.Contains($entraId)) { continue }
    $rjUsers = @($rjDevice.users | Where-Object { $null -ne $_ })
    $rjPrimaryUser = $rjUsers | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { "$($rjPrimaryUser.userName)" } else { "(none)" }
    $rjLastSeen = $null
    $rjLastSeenUser = ""
    foreach ($rjUser in $rjUsers) {
        $seen = ConvertTo-UtcDateTime -Value $rjUser.lastSeen
        if ($null -eq $seen) { continue }
        if ($null -eq $rjLastSeen -or $seen -gt $rjLastSeen) {
            $rjLastSeen = $seen
            $rjLastSeenUser = "$($rjUser.userName)"
        }
    }
    $reportData.Add([PSCustomObject]@{
            DeviceName            = "N/A"
            AzureAdDeviceId       = $entraId
            IntuneDeviceId        = "$($rjDevice.intuneDeviceId)"
            IntunePrimaryUser     = "(none)"
            RealmJoinPrimaryUser  = $rjPrimaryUserName
            Status                = "MissingInIntune"
            IntuneLastLogonUser   = "(none)"
            IntuneLastLogon       = "N/A"
            RealmJoinLastSeenUser = if ($rjLastSeenUser) { $rjLastSeenUser } else { "(none)" }
            RealmJoinLastSeen     = Format-ReportDateTime -Value $rjLastSeen
            PrimaryUserLastLogon  = "N/A"
            OtherUserLastLogon    = "N/A"
            PrimaryUserLogon      = "N/A"
            IntuneLastSync        = "N/A"
            Findings              = "MissingInIntune"
        })
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
    Write-RjRbLog -Message "Device scope filtering applied: $beforeScopeCount -> $($reportData.Count) device(s)" -Verbose
    Write-Output "Device scope filtering applied: $beforeScopeCount device(s) reduced to $($reportData.Count)."
}

# A device is in the report when at least one of its findings belongs to an enabled category.
$results = @($reportData | Where-Object {
        $rowFindings = @("$($_.Findings)" -split ',\s*' | Where-Object { $_ })
        $hit = $false
        foreach ($finding in $rowFindings) { if ($includedCategories -contains $finding) { $hit = $true } }
        $hit
    } | Sort-Object DeviceName)

$totalEvaluated = @($reportData | Where-Object { $_.Status -ne "MissingInIntune" }).Count
$matchCount = @($reportData | Where-Object { $_.Status -eq "Match" }).Count
$mismatchCount = @($reportData | Where-Object { $_.Status -eq "Mismatch" }).Count
$primaryUserDeletedCount = @($reportData | Where-Object { $_.Status -eq "PrimaryUserDeleted" }).Count
$notLoggingOnCount = @($reportData | Where-Object { $_.PrimaryUserLogon -eq "NotLoggingOn" }).Count
$missingInRjCount = @($reportData | Where-Object { $_.Status -eq "MissingInRealmJoin" }).Count
$missingInIntuneCount = @($reportData | Where-Object { $_.Status -eq "MissingInIntune" }).Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Intune devices evaluated: $totalEvaluated"
Write-Output "Primary user matching: $matchCount"
Write-Output "Primary user mismatch: $mismatchCount"
Write-Output "Primary user deleted in Entra ID: $primaryUserDeletedCount"
Write-Output "Primary user not logging on (window $PrimaryUserLogonDays days): $notLoggingOnCount"
Write-Output "Missing in RealmJoin: $missingInRjCount"
Write-Output "Missing in Intune: $missingInIntuneCount"
Write-Output "Devices in the report: $($results.Count)"
Write-RjRbLog -Message "Evaluated: $totalEvaluated; Match: $matchCount; Mismatch: $mismatchCount; PrimaryUserDeleted: $primaryUserDeletedCount; NotLoggingOn: $notLoggingOnCount; MissingInRealmJoin: $missingInRjCount; MissingInIntune: $missingInIntuneCount; in report: $($results.Count)" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFile = $null
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PrimaryUserMismatch_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "PrimaryUserMismatch_$($safeTenantName)_$(Get-Date -Format 'yyyyMMdd')"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $results.Count -gt 0) {
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
            Title                              = 'Primary User Mismatch'
            Tenant                             = $tenantDisplayName
            Generated                          = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'                  = $Version
            'Intune sync window (days)'        = $SyncThresholdDays
            'Primary user logon window (days)' = $PrimaryUserLogonDays
            'Categories'                       = ($includedCategories -join ', ')
            'Intune devices evaluated'         = $totalEvaluated
            'Devices in the report'            = $results.Count
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

if (-not $sendEmail) {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}
elseif ($results.Count -eq 0) {
    Write-Output ""
    Write-Output "No devices in the enabled categories - Intune and RealmJoin are in sync. Email report skipped."
    Write-RjRbLog -Message "No findings - email report skipped" -Verbose
}
else {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    $emailSubject = "Primary User Mismatch Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    # Only the enabled categories are listed; the evaluated total is always shown for context.
    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("| **Intune devices evaluated** | $totalEvaluated |")
    if ($IncludeMismatches) { $summaryLines.Add("| **Primary user mismatch** | $mismatchCount |") }
    if ($IncludePrimaryUserDeleted) { $summaryLines.Add("| **Primary user deleted in Entra ID** | $primaryUserDeletedCount |") }
    if ($IncludePrimaryUserNotLoggingOn) { $summaryLines.Add("| **Primary user not logging on** | $notLoggingOnCount |") }
    if ($IncludeMissingInRealmJoin) { $summaryLines.Add("| **Missing in RealmJoin** | $missingInRjCount |") }
    if ($IncludeMissingInIntune) { $summaryLines.Add("| **Missing in Intune** | $missingInIntuneCount |") }
    $summaryTable = "| Metric | Count |`n|--------|-------|`n" + ($summaryLines -join "`n")

    $maxDisplayDevices = 10
    $previewRows = @($results | Select-Object -First $maxDisplayDevices)
    $previewLines = @("| Device | Intune primary user | RealmJoin primary user | Last logon (Intune) | Last user seen (RealmJoin) | Findings |", "|---|---|---|---|---|---|")
    foreach ($row in $previewRows) {
        $previewLines += "| $($row.DeviceName) | $($row.IntunePrimaryUser) | $($row.RealmJoinPrimaryUser) | $($row.IntuneLastLogonUser) | $($row.RealmJoinLastSeenUser) | $($row.Findings) |"
    }
    $previewTable = $previewLines -join "`n"
    $xlsxFileName = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { "the Excel workbook" }

    $markdownContent = @"
# Primary User Mismatch Report

Tenant: **$tenantDisplayName**

Windows devices that synced with Intune in the last $SyncThresholdDays day(s), compared with the primary user and the logons RealmJoin recorded.

## Summary

$summaryTable

## Devices (first $($previewRows.Count) of $($results.Count))

$previewTable

## Attachments

The attached report file(s) contain every device in the enabled categories with all details.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# Primary User Mismatch Report

Tenant: **$tenantDisplayName**

## Summary

$summaryTable

## Attachments

- **$xlsxFileName**: Excel workbook with the complete list of devices

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option to obtain the raw CSV file.

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
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
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

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryValues = [ordered]@{
    "Intune devices evaluated"                                        = $totalEvaluated
    "Primary user matching"                                           = $matchCount
    "Primary user mismatch"                                           = $mismatchCount
    "Primary user deleted in Entra ID"                                = $primaryUserDeletedCount
    "Primary user not logging on (window $PrimaryUserLogonDays days)" = $notLoggingOnCount
    "Missing in RealmJoin"                                            = $missingInRjCount
    "Missing in Intune"                                               = $missingInIntuneCount
    "Devices in the report"                                           = $results.Count
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

# One table per category with the columns that explain the finding. A device with several findings appears in each of its tables.
$categoryTables = @(
    @{ Enabled = $IncludeMismatches; Title = "Primary user mismatch"; Filter = { $_.Status -eq "Mismatch" }; Columns = @("DeviceName", "IntunePrimaryUser", "RealmJoinPrimaryUser", "IntuneLastLogonUser", "RealmJoinLastSeenUser", "IntuneLastSync") }
    @{ Enabled = $IncludePrimaryUserDeleted; Title = "Primary user deleted"; Filter = { $_.Status -eq "PrimaryUserDeleted" }; Columns = @("DeviceName", "IntunePrimaryUser", "RealmJoinPrimaryUser", "IntuneLastLogonUser", "IntuneLastSync") }
    @{ Enabled = $IncludePrimaryUserNotLoggingOn; Title = "Primary user not logging on"; Filter = { $_.PrimaryUserLogon -eq "NotLoggingOn" }; Columns = @("DeviceName", "IntunePrimaryUser", "PrimaryUserLastLogon", "OtherUserLastLogon", "IntuneLastLogonUser", "RealmJoinLastSeenUser", "IntuneLastSync") }
    @{ Enabled = $IncludeMissingInRealmJoin; Title = "Missing in RealmJoin"; Filter = { $_.Status -eq "MissingInRealmJoin" }; Columns = @("DeviceName", "IntunePrimaryUser", "RealmJoinPrimaryUser", "IntuneLastLogonUser", "IntuneLastSync") }
    @{ Enabled = $IncludeMissingInIntune; Title = "Missing in Intune"; Filter = { $_.Status -eq "MissingInIntune" }; Columns = @("AzureAdDeviceId", "IntuneDeviceId", "RealmJoinPrimaryUser", "RealmJoinLastSeenUser", "RealmJoinLastSeen") }
)

foreach ($table in $categoryTables) {
    if (-not $table.Enabled) { continue }
    $rows = @($results | Where-Object $table.Filter | Select-Object -Property $table.Columns)
    $total = @($results | Where-Object $table.Filter).Count
    if ($rows.Count -gt 0) {
        Write-Output "$total device(s): $($table.Title)"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $table.Title })
        Write-Output $rows
    }
    else {
        Write-Output "No devices: $($table.Title)."
    }
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Removed temporary export directory: $tempDir" -Verbose
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
