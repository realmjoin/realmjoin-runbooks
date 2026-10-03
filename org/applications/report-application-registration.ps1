<#
	.SYNOPSIS
	Report all application registrations, including deleted ones

	.DESCRIPTION
	Lists every application registration in Entra ID, optionally including registrations deleted within the last 30 days, for inventory, review and audit purposes. Nothing is changed. The report can be sent by email or provided as a download link.

	.PARAMETER IncludeDeletedApps
	Also lists application registrations that were deleted within the last 30 days.

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
			"IncludeDeletedApps": {
				"DisplayName": "Include deleted registrations?"
			},
			"SendEmailReport": {
				"DisplayName": "Send the report by email?",
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
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
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
				"Select": {
					"Options": [
						{
							"Display": "CSV & XLSX",
							"ParameterValue": "CSV & XLSX"
						},
						{
							"Display": "CSV only",
							"ParameterValue": "CSV only"
						},
						{
							"Display": "XLSX only",
							"ParameterValue": "XLSX only"
						}
					],
					"ShowValue": false
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
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "IncludeDeletedApps",
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

param(
    [bool]$IncludeDeletedApps = $true,

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

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-application-registration",

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

$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Include Deleted Apps: $IncludeDeletedApps" -Verbose
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

if ($IncludeDeletedApps -notin $true, $false) {
    Write-RjRbLog -Message "Invalid value for IncludeDeletedApps. Please specify true or false." -Verbose
    throw "Invalid value for IncludeDeletedApps. Please specify true or false."
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

# Tenant id for the report rows comes from the Graph session; the display name for the email
# subject and body is read from /organization (needs Organization.Read.All, never fails the run)
$tenantId = (Get-MgContext).TenantId
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        if ($organizationResponse.value[0].id) {
            $tenantId = $organizationResponse.value[0].id
        }
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

#region App Registrations
Write-Output ""
Write-Output "Retrieving all App Registrations (this may take a while in large tenants)..."

$allAppRegs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
Write-Output "Found $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..."

# Service principals are read once and matched by appId instead of one lookup per app registration
$servicePrincipalsByAppId = $null
try {
    $servicePrincipalsByAppId = @{}
    foreach ($servicePrincipal in @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,appId,accountEnabled&`$top=999")) {
        if ($servicePrincipal.appId) { $servicePrincipalsByAppId["$($servicePrincipal.appId)".ToLower()] = $servicePrincipal }
    }
    Write-RjRbLog -Message "Service principals retrieved: $($servicePrincipalsByAppId.Count)" -Verbose
}
catch {
    $servicePrincipalsByAppId = $null
    Write-Output "WARNING: The service principals could not be read - the service principal status is shown as 'Unknown'. Error: $($_.Exception.Message)"
}

$appRegResults = @()
$processedCount = 0

foreach ($appReg in $allAppRegs) {
    $processedCount++
    if ($processedCount % 50 -eq 0) {
        Write-RjRbLog -Message "Processed $processedCount of $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..." -Verbose
    }

    # Create standardized object
    $tempObj = [PSCustomObject]@{
        AppId             = $appReg.appId
        AppRegObjectId    = $appReg.id
        DisplayName       = $appReg.displayName
        CreatedDateTime   = $appReg.createdDateTime
        PublisherDomain   = $appReg.publisherDomain
        SignInAudience    = $appReg.signInAudience
        AppRegPortalLink  = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($appReg.appId)"
        SpnObjectId       = ""
        SpnPortalLink     = ""
        AccountEnabled    = "Unknown"
        TenantId          = $tenantId
        IsDeleted         = $false
        HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
        HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
        SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
        CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
    }

    # Associated service principal; none exists for an app that was never consented in this tenant
    if ($null -ne $servicePrincipalsByAppId) {
        $spn = $servicePrincipalsByAppId["$($appReg.appId)".ToLower()]
        if ($spn) {
            $tempObj.SpnObjectId = $spn.id
            $tempObj.SpnPortalLink = "https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($spn.id)/appId/$($appReg.appId)"
            $tempObj.AccountEnabled = [bool]$spn.accountEnabled
        }
        else {
            $tempObj.AccountEnabled = "No service principal"
        }
    }

    $appRegResults += $tempObj
}

Write-RjRbLog -Message "Processed all $((($(($appRegResults) | Measure-Object).Count))) App Registrations" -Verbose
#endregion App Registrations

#region Deleted App Registrations
$deletedAppRegResults = @()

if ($IncludeDeletedApps) {
    Write-Output "Retrieving deleted App Registrations..."

    try {
        $deletedAppRegs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application"
        Write-Output "Found $((($(($deletedAppRegs) | Measure-Object).Count))) deleted App Registrations"

        foreach ($appReg in $deletedAppRegs) {
            $tempObj = [PSCustomObject]@{
                AppId             = $appReg.appId
                AppRegObjectId    = $appReg.id
                DisplayName       = $appReg.displayName
                CreatedDateTime   = $appReg.createdDateTime
                DeletedDateTime   = $appReg.deletedDateTime
                PublisherDomain   = $appReg.publisherDomain
                SignInAudience    = $appReg.signInAudience
                AppRegPortalLink  = "" # Not accessible for deleted apps
                SpnObjectId       = ""
                SpnPortalLink     = ""
                AccountEnabled    = $false
                TenantId          = $tenantId
                IsDeleted         = $true
                HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
                HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
                SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
                CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
            }

            $deletedAppRegResults += $tempObj
        }

        Write-RjRbLog -Message "Processed $((($(($deletedAppRegResults) | Measure-Object).Count))) deleted App Registrations" -Verbose
    }
    catch {
        Write-Output "WARNING: Could not retrieve deleted App Registrations, the report lists the active ones only: $($_.Exception.Message)"
    }
}
#endregion Deleted App Registrations

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Generate statistics
$activeAppCount = ($appRegResults | Measure-Object).Count
$deletedAppCount = ($deletedAppRegResults | Measure-Object).Count
$activeAppsWithSecrets = (($(($appRegResults | Where-Object { $_.HasSecrets }) | Measure-Object).Count))
$activeAppsWithCerts = (($(($appRegResults | Where-Object { $_.HasCertificates }) | Measure-Object).Count))
$enabledApps = (($appRegResults | Where-Object { $_.AccountEnabled -is [bool] -and $_.AccountEnabled }) | Measure-Object).Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Active App Registrations: $activeAppCount"
if ($IncludeDeletedApps) {
    Write-Output "Deleted App Registrations: $deletedAppCount"
}
Write-Output "Apps with Client Secrets: $activeAppsWithSecrets"
Write-Output "Apps with Certificates: $activeAppsWithCerts"

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AppRegReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and ($activeAppCount + $deletedAppCount) -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        # Export active App Registrations (if any)
        if ($activeAppCount -gt 0) {
            $activeAppRegCsv = Join-Path $tempDir "AppRegistrations_Active.csv"
            $appRegResults | Export-Csv -Path $activeAppRegCsv -NoTypeInformation -Encoding UTF8
            $reportFiles += $activeAppRegCsv
            Write-RjRbLog -Message "Exported active App Registrations to: $activeAppRegCsv" -Verbose
        }

        # Export deleted App Registrations (if any)
        if ($deletedAppCount -gt 0) {
            $deletedAppRegCsv = Join-Path $tempDir "AppRegistrations_Deleted.csv"
            $deletedAppRegResults | Export-Csv -Path $deletedAppRegCsv -NoTypeInformation -Encoding UTF8
            $reportFiles += $deletedAppRegCsv
            Write-RjRbLog -Message "Exported deleted App Registrations to: $deletedAppRegCsv" -Verbose
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet
        $xlsxPath = Join-Path $tempDir "AppRegistrations.xlsx"
        $workbookCoverSheet = [ordered]@{
            Title                       = 'Application Registration Report'
            Generated                   = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'           = $Version
            'Active App Registrations'  = $activeAppCount
            'Deleted App Registrations' = $deletedAppCount
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Active app registrations' = $appRegResults; 'Deleted app registrations' = $deletedAppRegResults }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
        Write-RjRbLog -Message "Exported App Registrations workbook to: $xlsxPath" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
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
        Write-Output "No App Registrations found - skipping the upload."
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

    $emailSubject = "App Registration Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

    # Create markdown content for email
    $markdownContent = @"
# Application Registration Report

This report provides a comprehensive overview of all Application Registrations in your Entra ID.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Active App Registrations** | $($appRegResults.Count) |
| **Deleted App Registrations** | $($deletedAppRegResults.Count) |
| **Enabled Service Principals** | $($enabledApps) |
| **Apps with Client Secrets** | $($activeAppsWithSecrets) |
| **Apps with Certificates** | $($activeAppsWithCerts) |

## Report Details

### Active Application Registrations
$(if ($ReportFileFormat -ne 'XLSX only') { "- **File:** AppRegistrations_Active.csv" })
- **Count:** $($appRegResults.Count) applications
- Contains all currently active App Registrations with their associated Service Principals

$(if ($deletedAppRegResults.Count -gt 0) {
@"

### Deleted Application Registrations
$(if ($ReportFileFormat -ne 'XLSX only') { "- **File:** AppRegistrations_Deleted.csv" })
- **Count:** $($deletedAppRegResults.Count) applications
- Contains App Registrations that have been deleted but are still recoverable
"@
} else {
"### Deleted Application Registrations
No deleted App Registrations found in the tenant."
})

$(if ($ReportFileFormat -ne 'CSV only') {
@"

### Excel Workbook
- **File:** AppRegistrations.xlsx
- Contains the Active and Deleted lists as separate worksheets in a formatted Excel workbook
"@
})

## Security Recommendations

### Applications with Client Secrets
$($activeAppsWithSecrets) applications have client secrets configured. Please review these regularly:
- Ensure secrets are rotated according to your security policy
- Remove unused secrets to reduce attack surface
- Consider migrating to certificate-based authentication where possible

### Applications with Certificates
$($activeAppsWithCerts) applications use certificate-based authentication:
- Monitor certificate expiration dates
- Ensure certificates are stored securely
- Have a renewal process in place

## Data Export Information

The attached report file(s) contain detailed information including:
- Application ID and Object ID
- Display Name and Creation Date
- Publisher Domain and Sign-in Audience
- Authentication method details (secrets/certificates)
- Direct links to Azure Portal for management

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
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
            $markdownFallback = @"
# Application Registration Report

This report provides a comprehensive overview of all Application Registrations in your Entra ID.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Active App Registrations** | $($appRegResults.Count) |
| **Deleted App Registrations** | $($deletedAppRegResults.Count) |
| **Enabled Service Principals** | $($enabledApps) |
| **Apps with Client Secrets** | $($activeAppsWithSecrets) |
| **Apps with Certificates** | $($activeAppsWithCerts) |

## Data Files

- **AppRegistrations.xlsx**: Excel workbook with the Active and Deleted lists (one worksheet per dataset)

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option to obtain the raw CSV files.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath -and (Test-Path -Path $xlsxPath)) {
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

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = [System.Collections.Generic.List[object]]::new()
$summaryRows.Add([PSCustomObject]@{ Metric = "Active app registrations"; Value = [int]$activeAppCount })
if ($IncludeDeletedApps) {
    $summaryRows.Add([PSCustomObject]@{ Metric = "Deleted app registrations (last 30 days)"; Value = [int]$deletedAppCount })
}
$summaryRows.Add([PSCustomObject]@{ Metric = "Apps with client secrets"; Value = [int]$activeAppsWithSecrets })
$summaryRows.Add([PSCustomObject]@{ Metric = "Apps with certificates"; Value = [int]$activeAppsWithCerts })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows.ToArray()

# One table per list; the deleted registrations only when they were requested
$resultTables = @(
    @{ Enabled = $true; Title = "Active app registrations"; Rows = $appRegResults; Columns = @("DisplayName", "AppId", "CreatedDateTime", "SignInAudience", "PublisherDomain", "AccountEnabled", "SecretsCount", "CertificatesCount") }
    @{ Enabled = $IncludeDeletedApps; Title = "Deleted app registrations"; Rows = $deletedAppRegResults; Columns = @("DisplayName", "AppId", "DeletedDateTime", "CreatedDateTime", "SignInAudience") }
)

foreach ($table in $resultTables) {
    if (-not $table.Enabled) { continue }
    $total = @($table.Rows).Count
    if ($total -gt 0) {
        Write-Output "$total registration(s): $($table.Title)"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $table.Title })
        Write-Output @($table.Rows | Sort-Object -Property DisplayName | Select-Object -Property $table.Columns)
    }
    else {
        Write-Output "No registrations: $($table.Title)."
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
