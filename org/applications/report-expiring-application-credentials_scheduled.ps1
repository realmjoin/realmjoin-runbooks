<#
	.SYNOPSIS
	Report expiring client secrets and certificates of app registrations

	.DESCRIPTION
	Lists the client secrets and certificates of application registrations with their expiry dates. The list can be limited to credentials that expire within a chosen number of days and to certain applications. The results also appear as tables in the Output Data tab of the run. Nothing is changed. The report can be sent by email or provided as a download link.

	.PARAMETER listOnlyExpiring
	Only credentials that expire within "Days before expiry", or all credentials including expired ones.

	.PARAMETER Days
	Credentials that expire within this many days count as about to expire. Not used when all credentials are listed.

	.PARAMETER CredentialType
	Client secrets, certificates, or both.

	.PARAMETER ApplicationIds
	Limits the report to these application (client) IDs, separated by commas. Leave empty for all applications.

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

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"listOnlyExpiring": {
				"DisplayName": "Which credentials?",
				"Select": {
					"Options": [
						{
							"Display": "List only credentials about to expire",
							"ParameterValue": true
						},
						{
							"Display": "List all credentials",
							"ParameterValue": false,
							"Customization": {
								"Hide": [ "Days" ]
							}
						}
					]
				}
			},
			"Days": {
				"DisplayName": "Days before expiry"
			},
			"CredentialType": {
				"DisplayName": "Credential type",
				"SelectSimple": {
					"Client secrets and certificates": "Both",
					"Client secrets only": "ClientSecrets",
					"Certificates only": "Certificates"
				}
			},
			"ApplicationIds": {
				"DisplayName": "Application IDs"
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
				"SelectSimple": {
					"CSV & XLSX": "CSV & XLSX",
					"CSV only": "CSV only",
					"XLSX only": "XLSX only"
				}
			},
			"CreateDownloadLink": {
				"DisplayName": "Create a download link?",
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
			"SendEmailReport": {
				"DisplayName": "Send the report by email?",
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
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "ApplicationIds",
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

# Suppress false positive from PSScriptAnalyzer - CredentialType is a type selector (Both/ClientSecrets/Certificates), not a password
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialType")]
param(
    [bool] $listOnlyExpiring = $true,

    [int] $Days = 30,

    [ValidateSet("Both", "ClientSecrets", "Certificates")]
    [string] $CredentialType = "Both",

    [string] $ApplicationIds,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-expiring-app-credentials",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [bool]$SendEmailReport = $false,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

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

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "List Only Expiring: $listOnlyExpiring" -Verbose
Write-RjRbLog -Message "Days before expiry: $Days" -Verbose
Write-RjRbLog -Message "Credential Type: $CredentialType" -Verbose
Write-RjRbLog -Message "Application IDs: $ApplicationIds" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
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

# Tenant display name for the email subject and body (needs Organization.Read.All, never fails the run)
$tenantId = (Get-MgContext).TenantId
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

Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Retrieving application credentials (this may take a while in large tenants)..."

# Split the comma-separated application IDs into an array and trim whitespace
$ApplicationIdArray = @()
if ($ApplicationIds) {
    $ApplicationIdArray = $ApplicationIds -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    Write-RjRbLog -Message "Filtering by $($ApplicationIdArray.Count) Application ID(s)" -Verbose
}

# Determine which credential types to process
$processCertificates = ($CredentialType -eq "Both" -or $CredentialType -eq "Certificates")
$processClientSecrets = ($CredentialType -eq "Both" -or $CredentialType -eq "ClientSecrets")

Write-RjRbLog -Message "Processing Certificates: $processCertificates" -Verbose
Write-RjRbLog -Message "Processing Client Secrets: $processClientSecrets" -Verbose

[array]$apps = @()
$apps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"

Write-Output "Found $((($(($apps) | Measure-Object).Count))) applications/service principals"

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$date = Get-Date
$credentialResults = @()

foreach ($app in $apps) {
    if ($ApplicationIdArray -and ($ApplicationIdArray.Count -gt 0) -and ($app.appId -notin $ApplicationIdArray)) {
        continue
    }

    if (($app.keyCredentials) -or ($app.passwordCredentials)) {
        # Process Certificate Credentials (only if filter allows)
        if ($processCertificates) {
            $app.keyCredentials | ForEach-Object {
                $enddate = [datetime]$_.endDateTime
                $startdate = [datetime]$_.startDateTime
                $daysLeft = (New-TimeSpan -Start $date -End $enddate).days

                if ($listOnlyExpiring) {
                    # Only include credentials that are expiring (0 to $Days days left), exclude already expired (negative days)
                    if ($daysLeft -ge 0 -and $daysLeft -le $Days) {
                        $tempObj = [PSCustomObject]@{
                            AppDisplayName = $app.displayName
                            AppId          = $app.appId
                            AppObjectId    = $app.id
                            CredentialType = "Certificate"
                            CredentialName = $_.displayName
                            CredentialId   = $_.keyId
                            StartDateTime  = $startdate
                            EndDateTime    = $enddate
                            DaysLeft       = $daysLeft
                            IsExpired      = ($daysLeft -lt 0)
                            Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le $Days) { "Warning" } else { "Valid" }
                        }
                        $credentialResults += $tempObj
                    }
                }
                else {
                    # Include all credentials (expired, expiring, and valid)
                    $tempObj = [PSCustomObject]@{
                        AppDisplayName = $app.displayName
                        AppId          = $app.appId
                        AppObjectId    = $app.id
                        CredentialType = "Certificate"
                        CredentialName = $_.displayName
                        CredentialId   = $_.keyId
                        StartDateTime  = $startdate
                        EndDateTime    = $enddate
                        DaysLeft       = $daysLeft
                        IsExpired      = ($daysLeft -lt 0)
                        Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le 30) { "Warning" } else { "Valid" }
                    }
                    $credentialResults += $tempObj
                }
            }
        }

        # Process Client Secret Credentials (only if filter allows)
        if ($processClientSecrets) {
            $app.passwordCredentials | ForEach-Object {
                $enddate = [datetime]$_.endDateTime
                $startdate = [datetime]$_.startDateTime
                $daysLeft = (New-TimeSpan -Start $date -End $enddate).days

                if ($listOnlyExpiring) {
                    # Only include credentials that are expiring (0 to $Days days left), exclude already expired (negative days)
                    if ($daysLeft -ge 0 -and $daysLeft -le $Days) {
                        $tempObj = [PSCustomObject]@{
                            AppDisplayName = $app.displayName
                            AppId          = $app.appId
                            AppObjectId    = $app.id
                            CredentialType = "Client Secret"
                            CredentialName = $_.displayName
                            CredentialId   = $_.keyId
                            StartDateTime  = $startdate
                            EndDateTime    = $enddate
                            DaysLeft       = $daysLeft
                            IsExpired      = ($daysLeft -lt 0)
                            Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le $Days) { "Warning" } else { "Valid" }
                        }
                        $credentialResults += $tempObj
                    }
                }
                else {
                    # Include all credentials (expired, expiring, and valid)
                    $tempObj = [PSCustomObject]@{
                        AppDisplayName = $app.displayName
                        AppId          = $app.appId
                        AppObjectId    = $app.id
                        CredentialType = "Client Secret"
                        CredentialName = $_.displayName
                        CredentialId   = $_.keyId
                        StartDateTime  = $startdate
                        EndDateTime    = $enddate
                        DaysLeft       = $daysLeft
                        IsExpired      = ($daysLeft -lt 0)
                        Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le 30) { "Warning" } else { "Valid" }
                    }
                    $credentialResults += $tempObj
                }
            }
        }
    }
}

Write-RjRbLog -Message "Processed $((($(($credentialResults) | Measure-Object).Count))) credentials" -Verbose

# Sort credentials by days left (ascending) to show most critical first
$credentialResults = @($credentialResults | Sort-Object DaysLeft)

# Generate statistics
$appsInScope = @($apps | Where-Object { -not $ApplicationIdArray -or ($_.appId -in $ApplicationIdArray) }).Count
$totalCreds = (($(($credentialResults) | Measure-Object).Count))
$expiredCreds = (($(($credentialResults | Where-Object { $_.IsExpired }) | Measure-Object).Count))
$criticalCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired }) | Measure-Object).Count))
$warningCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Warning" }) | Measure-Object).Count))
$validCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Valid" }) | Measure-Object).Count))
$secrets = (($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" }) | Measure-Object).Count))
$certs = (($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" }) | Measure-Object).Count))

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Applications evaluated: $appsInScope"
Write-Output "Credentials listed: $totalCreds (client secrets: $secrets, certificates: $certs)"
if ($listOnlyExpiring) {
    Write-Output "Expiring within $Days days - Critical (7 days or less): $criticalCreds | Warning: $warningCreds"
}
else {
    Write-Output "Status - Expired: $expiredCreds | Critical: $criticalCreds | Warning: $warningCreds | Valid: $validCreds"
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

# Name of the Excel worksheet with the complete credential list; Excel limits sheet names to 31 characters
$tableTitle = if ($listOnlyExpiring) { "Expiring within $Days days" } else { "All application credentials" }

$reportFiles = @()
$xlsxPath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AppCredsExpiry_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$credsCsv = Join-Path $tempDir "AppCredsExpiry_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$credsXlsx = [System.IO.Path]::ChangeExtension($credsCsv, 'xlsx')

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $totalCreds -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        $credentialResults | Export-Csv -Path $credsCsv -NoTypeInformation -Encoding UTF8
        $reportFiles += $credsCsv
        Write-RjRbLog -Message "Exported application credentials to: $credsCsv" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = $credsXlsx
        $credentialResults | Export-RjRbXlsx -Path $xlsxPath -WorksheetName $tableTitle
        $reportFiles += $xlsxPath
        Write-RjRbLog -Message "Exported application credentials to: $xlsxPath" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($totalCreds -eq 0) {
    Write-RjRbLog -Message "No credentials found matching the filter criteria - skipping the report file export" -Verbose
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
        Write-Output "No credentials found matching the filter criteria - skipping the upload."
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
else {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    # Create markdown content for email - different content based on mode
    if ($listOnlyExpiring) {
        # EXPIRING MODE: Focus on urgency and action items (NO EXPIRED CREDENTIALS)
        $markdownContent = @"
# Application Credentials Expiry Alert

**Notice:** This report shows credentials that are **expiring within $Days days**.

## Action Required Summary

| Status | Count | Action Needed |
|--------|-------|---------------|
| **Critical (≤7 days)** | $($criticalCreds) | **URGENT** - Renew within 7 days |
| **Warning (≤$($Days) days)** | $($warningCreds) | **SOON** - Schedule renewal |
| **Total Requiring Attention** | **$($totalCreds)** | Review attached report file |

$(if ($criticalCreds -gt 0) {
@"
## CRITICAL - Expiring Within 7 Days ($($criticalCreds))

These credentials will expire very soon and require **urgent renewal**:

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired } | Select-Object -First 15 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | **$($_.DaysLeft)** |"
}) -join "`n")

$(if ($criticalCreds -gt 15) { "*... and $($criticalCreds - 15) more (see attached report file)*" })

**Action:** Schedule credential renewal within the next few days.

"@
})

$(if ($warningCreds -gt 0) {
@"
## WARNING - Expiring Within $($Days) Days ($($warningCreds))

These credentials should be renewed soon:

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Warning" } | Select-Object -First 15 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($warningCreds -gt 15) { "*... and $($warningCreds - 15) more (see attached report file)*" })

**Action:** Plan credential renewal within the next few weeks.

"@
})

## Next Steps

### Immediate Actions (Priority Order)

1. $(if ($criticalCreds -gt 0) { "**Renew $($criticalCreds) critical credential(s)** expiring within 7 days" } else { "No critical credentials expiring soon" })
2. $(if ($warningCreds -gt 0) { "**Schedule renewal for $($warningCreds) credential(s)** expiring within $($Days) days" } else { "No credentials in warning period" })

### Important Information

- **Credential Type Filter:** $($CredentialType)
- **Credential Types in Report:** $($secrets) Client Secrets, $($certs) Certificates
- **Filter Applied:** Showing only credentials expiring within $($Days) days (excluding already expired)
$(if ($ApplicationIdArray -and ($ApplicationIdArray.Count -gt 0)) { "- **Application Filter:** Limited to $($ApplicationIdArray.Count) specific application(s)" })
- **Note:** Already expired credentials are not included in this report

### Report File Details

The attached report file(s) contain complete information for all $($totalCreds) credentials requiring attention:
- Application details (Name, ID, Object ID)
- Credential type and name
- Exact expiration dates and days remaining
- Current status classification

**Use the report file(s) to prioritize your renewal tasks and track progress.**

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }
    else {
        # ALL MODE: Comprehensive overview with statistics
        $markdownContent = @"
# Application Credentials Overview Report

This is a comprehensive inventory of **all** Application Registration credentials in your tenant.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Credentials** | $($totalCreds) |
| **Client Secrets** | $($secrets) |
| **Certificates** | $($certs) |
|  **Expired** | $($expiredCreds) |
|  **Critical (≤7 days)** | $($criticalCreds) |
|  **Warning (≤30 days)** | $($warningCreds) |
|  **Valid (>30 days)** | $($validCreds) |

$(if ($expiredCreds -gt 0) {
@"
## Expired Credentials ($($expiredCreds))

These credentials have already expired:

| Application | Credential Type | Name | Expired Since |
|-------------|----------------|------|---------------|
$(($credentialResults | Where-Object { $_.IsExpired } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $(([Math]::Abs($_.DaysLeft))) days ago |"
}) -join "`n")

$(if ($expiredCreds -gt 10) { "*... and $($expiredCreds - 10) more (see attached report file)*" })


"@
})

$(if ($criticalCreds -gt 0) {
@"
## Critical - Expiring Soon (≤7 days) ($($criticalCreds))

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($criticalCreds -gt 10) { "*... and $($criticalCreds - 10) more (see attached report file)*" })


"@
})

$(if ($warningCreds -gt 0) {
@"
## Warning - Expiring Soon (≤30 days) ($($warningCreds))

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Warning" } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($warningCreds -gt 10) { "*... and $($warningCreds - 10) more (see attached report file)*" })


"@
})

## Credential Health Overview

### Current Status

- **Healthy:** $($validCreds) credentials with >30 days remaining
- **Attention Needed:** $($expiredCreds + $criticalCreds + $warningCreds) credentials require action
- **Success Rate:** $(if ($totalCreds -gt 0) { [math]::Round(($validCreds / $totalCreds) * 100, 1) } else { 0 })% of credentials are in good standing

### Breakdown by Type

- **Client Secrets:** $($secrets) total
  - Expired: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" -and $_.IsExpired }) | Measure-Object).Count))
  - Expiring Soon: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" -and ($_.Status -eq "Critical" -or $_.Status -eq "Warning") }) | Measure-Object).Count))

- **Certificates:** $($certs) total
  - Expired: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" -and $_.IsExpired }) | Measure-Object).Count))
  - Expiring Soon: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" -and ($_.Status -eq "Critical" -or $_.Status -eq "Warning") }) | Measure-Object).Count))

## Recommendations

### Immediate Actions

$(if ($expiredCreds -gt 0) {
"- **$($expiredCreds) expired credential(s)** - Review and renew or remove if no longer needed"
} else {
"- No expired credentials found"
})

$(if ($criticalCreds -gt 0) {
"- **$($criticalCreds) critical credential(s) expiring within 7 days** - Schedule urgent renewal"
})

$(if ($warningCreds -gt 0) {
"- **$($warningCreds) credential(s) expiring within 30 days** - Plan renewal activities"
})

### Best Practices

- **Regular Rotation:** Rotate credentials every 6-12 months according to your security policy
- **Automation:** Set up automated alerts for credentials expiring within 30 days
- **Certificate Preference:** Consider migrating to certificate-based authentication where possible
- **Documentation:** Maintain a credential renewal schedule and document processes
- **Cleanup:** Remove unused or expired credentials to reduce security risks
- **Monitoring:** Review this report monthly to maintain credential health

## Data Export Information

The attached report file(s) contain the complete inventory of all $($totalCreds) credentials:

- **Credential Type Filter:** $($CredentialType)
- Application Display Name and ID
- Credential Type (Client Secret or Certificate)
- Credential Name and ID
- Start and End DateTime
- Days remaining until expiry
- Current status classification (Expired, Critical, Warning, Valid)

**Use this data for:**
- Credential lifecycle management
- Compliance reporting
- Renewal planning and tracking
- Security audits

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }

    $dateStr = Get-Date -Format 'yyyy-MM-dd'
    $emailSubject = if ($listOnlyExpiring) {
        "Credentials Expiring Alert (≤$($Days) days) - $($tenantDisplayName) - $($dateStr)"
    }
    else {
        "Application Credentials Inventory - $($tenantDisplayName) - $($dateStr)"
    }

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
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
        if ($reportFiles.Count -gt 0) {
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath -and (Test-Path -Path $xlsxPath)) {
                $markdownFallback = @"
# $(if ($listOnlyExpiring) { "Application Credentials Expiry Alert" } else { "Application Credentials Overview Report" })

## Summary

| Metric | Count |
|--------|-------|
| **Total Credentials** | $($totalCreds) |
| **Client Secrets** | $($secrets) |
| **Certificates** | $($certs) |
| **Critical (≤7 days)** | $($criticalCreds) |
| **Warning** | $($warningCreds) |

## Data Files

- **$(Split-Path $xlsxPath -Leaf)**: Formatted Excel workbook with the complete credential list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

                Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        Write-Output "Email report sent to '$EmailTo'."
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last on purpose: email sending and the storage upload can take a while with many credentials.
# Every table has its own RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

$warningLabel = if (-not $listOnlyExpiring) { "Warning (8 to 30 days)" } elseif ($Days -ge 8) { "Warning (8 to $Days days)" } else { "Warning" }
$summaryRows = [System.Collections.Generic.List[object]]::new()
$summaryRows.Add([PSCustomObject]@{ Metric = "Applications evaluated"; Value = [int]$appsInScope })
$summaryRows.Add([PSCustomObject]@{ Metric = "Credentials listed"; Value = [int]$totalCreds })
$summaryRows.Add([PSCustomObject]@{ Metric = "Client secrets"; Value = [int]$secrets })
$summaryRows.Add([PSCustomObject]@{ Metric = "Certificates"; Value = [int]$certs })
if (-not $listOnlyExpiring) {
    $summaryRows.Add([PSCustomObject]@{ Metric = "Expired"; Value = [int]$expiredCreds })
}
$summaryRows.Add([PSCustomObject]@{ Metric = "Critical (7 days or less)"; Value = [int]$criticalCreds })
$summaryRows.Add([PSCustomObject]@{ Metric = $warningLabel; Value = [int]$warningCreds })
if (-not $listOnlyExpiring) {
    $summaryRows.Add([PSCustomObject]@{ Metric = "Valid (more than 30 days)"; Value = [int]$validCreds })
}
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows.ToArray()

# One table per status, most urgent first. Expired and valid credentials only exist when all credentials are listed.
$credentialColumns = @("AppDisplayName", "AppId", "CredentialType", "CredentialName", "EndDateTime", "DaysLeft")
$statusTables = @(
    @{ Enabled = (-not $listOnlyExpiring); Title = "Expired credentials"; Status = "Expired"; Columns = $credentialColumns }
    @{ Enabled = $true; Title = "Critical credentials"; Status = "Critical"; Columns = $credentialColumns }
    @{ Enabled = $true; Title = "Warning credentials"; Status = "Warning"; Columns = $credentialColumns }
    @{ Enabled = (-not $listOnlyExpiring); Title = "Valid credentials"; Status = "Valid"; Columns = @("AppDisplayName", "AppId", "CredentialType", "CredentialName", "StartDateTime", "EndDateTime", "DaysLeft") }
)

foreach ($table in $statusTables) {
    if (-not $table.Enabled) { continue }
    $statusRows = @($credentialResults | Where-Object { $_.Status -eq $table.Status })
    $total = $statusRows.Count
    if ($total -gt 0) {
        Write-Output "$total credential(s): $($table.Title)"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $table.Title })
        Write-Output @($statusRows | Select-Object -Property $table.Columns)
    }
    else {
        Write-Output "No credentials: $($table.Title)."
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

# Remove the temporary report files (email and download link)
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
