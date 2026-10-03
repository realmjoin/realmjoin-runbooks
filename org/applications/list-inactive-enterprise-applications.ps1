<#
	.SYNOPSIS
	List enterprise applications with no recent sign-ins

	.DESCRIPTION
	Finds enterprise applications that nobody has signed in to for a given number of days, plus those that were never used, so you can decide whether they are still needed. The check uses the service principal sign-in activity report, which keeps the last sign-in date of every application. Nothing is changed. Needs a Microsoft Entra ID P1 or P2 license. The report can be sent by email or provided as a download link.

	.PARAMETER Days
	Applications with no sign-in for at least this many days are listed as inactive.

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
			"Days": {
				"DisplayName": "Days without sign-in"
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
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "Days",
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
    [int] $Days = 90,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "list-inactive-enterprise-applications",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" })]
    [string] $ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" })]
    [string] $StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" })]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    [bool] $SendEmailReport = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" })]
    [string] $EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" })]
    [string] $BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" })]
    [string] $BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" })]
    [string] $BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string] $BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string] $BrandingTextColor,

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

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
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

# Get tenant information for the email report (needs Organization.Read.All)
$tenantDisplayName = "Unknown Tenant"
if ($sendEmail) {
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($tenantInfo.value -and ($tenantInfo.value | Measure-Object).Count -gt 0 -and $tenantInfo.value[0].displayName) {
            $tenantDisplayName = $tenantInfo.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Retrieving enterprise applications and their sign-in activity (this may take a while in large tenants)..."

# All service principals of the tenant. appDisplayName is not populated for every service principal,
# displayName serves as fallback so the report shows a readable name wherever one exists.
$allServicePrincipals = @()
try {
    $servicePrincipalUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,appId,appDisplayName,displayName&`$top=999"
    $allServicePrincipals = @(Get-GraphPagedResult -Uri $servicePrincipalUri)
}
catch {
    Write-Error "Listing service principals failed. Missing permissions (Directory.Read.All)? Error details: $($_)" -ErrorAction Stop
}
Write-RjRbLog -Message "Service principals found: $(($allServicePrincipals | Measure-Object).Count)" -Verbose

# Last sign-in per application, taken from the Microsoft Entra "Service principal sign-in activity" report.
# The report holds the last activity date per service principal (delegated and app-only, as client and as
# resource) and is therefore not bound to the retention period of the sign-in logs, which keep only the last
# 7 days (Microsoft Entra ID Free) resp. 30 days (Microsoft Entra ID P1/P2) of individual sign-in events.
$lastSignInByAppId = @{}
try {
    $signInActivities = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/reports/servicePrincipalSignInActivities")
    foreach ($activity in $signInActivities) {
        $activityAppId = [string]$activity.appId
        if (-not $activityAppId) {
            continue
        }
        $lastSignInValue = $activity.lastSignInActivity.lastSignInDateTime
        if ($lastSignInValue) {
            $lastSignInByAppId[$activityAppId] = $lastSignInValue
        }
    }
}
catch {
    Write-Error "Reading the service principal sign-in activity report failed. The report requires the AuditLog.Read.All permission and a Microsoft Entra ID P1 or P2 license. Error details: $($_)" -ErrorAction Stop
}
Write-RjRbLog -Message "Applications with a recorded sign-in: $($lastSignInByAppId.Count)" -Verbose
Write-Output "Found $(($allServicePrincipals | Measure-Object).Count) enterprise application(s), $($lastSignInByAppId.Count) with a recorded sign-in."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$nowUtc = (Get-Date).ToUniversalTime()
$thresholdUtc = $nowUtc.AddDays(-$Days)

$inactiveApps = @()
$neverUsedApps = @()

foreach ($servicePrincipal in $allServicePrincipals) {
    $appId = [string]$servicePrincipal.appId
    $displayName = ""
    if ($servicePrincipal.appDisplayName) {
        $displayName = [string]$servicePrincipal.appDisplayName
    }
    elseif ($servicePrincipal.displayName) {
        $displayName = [string]$servicePrincipal.displayName
    }

    $lastSignInUtc = $null
    if ($appId -and $lastSignInByAppId.ContainsKey($appId)) {
        $rawLastSignIn = $lastSignInByAppId[$appId]
        if ($rawLastSignIn -is [datetime]) {
            $lastSignInUtc = ([datetime]$rawLastSignIn).ToUniversalTime()
        }
        else {
            $parsedLastSignIn = [datetime]::MinValue
            if ([datetime]::TryParse([string]$rawLastSignIn, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedLastSignIn)) {
                $lastSignInUtc = $parsedLastSignIn.ToUniversalTime()
            }
            else {
                Write-RjRbLog -Message "Unreadable last sign-in date '$($rawLastSignIn)' for application $($appId) - counted as never used" -Verbose
            }
        }
    }

    if ($null -eq $lastSignInUtc) {
        $neverUsedApps += [PSCustomObject]@{
            AppDisplayName     = $displayName
            AppId              = $appId
            ServicePrincipalId = [string]$servicePrincipal.id
        }
        continue
    }

    if ($lastSignInUtc -le $thresholdUtc) {
        $inactiveApps += [PSCustomObject]@{
            AppDisplayName      = $displayName
            AppId               = $appId
            ServicePrincipalId  = [string]$servicePrincipal.id
            LastSignIn          = $lastSignInUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
            DaysSinceLastSignIn = [int][Math]::Floor(($nowUtc - $lastSignInUtc).TotalDays)
        }
    }
}

# Longest inactivity first, applications without any sign-in alphabetically
$inactiveApps = @($inactiveApps | Sort-Object -Property DaysSinceLastSignIn -Descending)
$neverUsedApps = @($neverUsedApps | Sort-Object -Property AppDisplayName)

$servicePrincipalCount = ($allServicePrincipals | Measure-Object).Count
$inactiveCount = ($inactiveApps | Measure-Object).Count
$neverUsedCount = ($neverUsedApps | Measure-Object).Count
$totalFound = $inactiveCount + $neverUsedCount

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Enterprise applications evaluated: $servicePrincipalCount"
Write-Output "Inactive (no sign-in for $Days days or more): $inactiveCount"
Write-Output "No sign-in recorded: $neverUsedCount"

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "InactiveEnterpriseApps_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$fileName_Inactive = "inactive-enterprise-apps.csv"
$fileName_NeverUsed = "never-used-enterprise-apps.csv"
$fileName_Xlsx = "inactive-enterprise-apps.xlsx"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $totalFound -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        # Export inactive applications (last sign-in older than the threshold), if any
        if ($inactiveCount -gt 0) {
            $csvPath_Inactive = Join-Path $tempDir $fileName_Inactive
            $inactiveApps | Export-Csv -Path $csvPath_Inactive -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvPath_Inactive
            Write-RjRbLog -Message "Exported $inactiveCount inactive application(s) to CSV: $csvPath_Inactive" -Verbose
        }

        # Export applications without any sign-in record, if any
        if ($neverUsedCount -gt 0) {
            $csvPath_NeverUsed = Join-Path $tempDir $fileName_NeverUsed
            $neverUsedApps | Export-Csv -Path $csvPath_NeverUsed -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvPath_NeverUsed
            Write-RjRbLog -Message "Exported $neverUsedCount application(s) without sign-in to CSV: $csvPath_NeverUsed" -Verbose
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet
        $xlsxPath = Join-Path $tempDir $fileName_Xlsx
        $workbookCoverSheet = [ordered]@{
            Title                                = 'Inactive Enterprise Applications'
            Generated                            = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'                    = $Version
            'Days threshold'                     = $Days
            'Inactive Applications'              = $inactiveCount
            'Applications Without Sign-in Record' = $neverUsedCount
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Inactive applications' = $inactiveApps; 'No sign-in recorded' = $neverUsedApps }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
        Write-RjRbLog -Message "Exported the applications workbook to: $xlsxPath" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($totalFound -eq 0) {
    Write-RjRbLog -Message "No inactive applications found - skipping the report file export" -Verbose
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
        Write-Output "No inactive applications found - skipping the upload."
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

    if ($totalFound -eq 0) {
        # No inactive applications found - send positive message without attachments
        $markdownContent = @"
# Inactive Enterprise Applications Report

## Summary

**No inactive enterprise applications were found** in your tenant. Every enterprise application has sign-in activity within the last $Days days.

**Inactivity threshold:** $Days days

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Inactive Enterprise Applications Report - No Inactive Applications Found"
    }
    else {
        # Inactive applications found - prepare detailed report (files were already exported above)
        $markdownContent = @"
# Inactive Enterprise Applications Report

## Summary

This report lists enterprise applications in your tenant without recent sign-in activity, based on the Microsoft Entra service principal sign-in activity report.

| Metric | Count |
|--------|-------|
| **Inactive applications (last sign-in more than $Days days ago)** | $inactiveCount |
| **Applications without any sign-in record** | $neverUsedCount |

**Inactivity threshold:** $Days days

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only' -and $inactiveCount -gt 0) { "- **$($fileName_Inactive)**: Applications whose last sign-in is more than $Days days ago (CSV)" })
$(if ($ReportFileFormat -ne 'XLSX only' -and $neverUsedCount -gt 0) { "- **$($fileName_NeverUsed)**: Applications without any recorded sign-in (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_Xlsx)**: Both lists as separate worksheets in a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Inactive Enterprise Applications Report - $totalFound Application(s) Found"
    }

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
    try {
        # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
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
# Inactive Enterprise Applications Report

## Summary

| Metric | Count |
|--------|-------|
| **Inactive applications (last sign-in more than $Days days ago)** | $inactiveCount |
| **Applications without any sign-in record** | $neverUsedCount |

**Inactivity threshold:** $Days days

## Data Files

- **$($fileName_Xlsx)**: Formatted Excel workbook with both lists as separate worksheets

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

$summaryRows = @(
    [PSCustomObject]@{ Metric = "Enterprise applications evaluated"; Value = [int]$servicePrincipalCount }
    [PSCustomObject]@{ Metric = "Days without sign-in (threshold)"; Value = [int]$Days }
    [PSCustomObject]@{ Metric = "Inactive applications"; Value = [int]$inactiveCount }
    [PSCustomObject]@{ Metric = "No sign-in recorded"; Value = [int]$neverUsedCount }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

# One table per result list with the columns that explain the finding
$resultTables = @(
    @{ Title = "Inactive applications"; Rows = $inactiveApps; Columns = @("AppDisplayName", "AppId", "LastSignIn", "DaysSinceLastSignIn") }
    @{ Title = "No sign-in recorded"; Rows = $neverUsedApps; Columns = @("AppDisplayName", "AppId") }
)

foreach ($table in $resultTables) {
    $total = @($table.Rows).Count
    if ($total -gt 0) {
        Write-Output "$total application(s): $($table.Title)"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $table.Title })
        Write-Output @($table.Rows | Select-Object -Property $table.Columns)
    }
    else {
        Write-Output "No applications: $($table.Title)."
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
