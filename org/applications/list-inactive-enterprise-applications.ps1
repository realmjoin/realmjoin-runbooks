<#
    .SYNOPSIS
    List enterprise applications with no recent sign-ins

    .DESCRIPTION
    This runbook identifies enterprise applications with no recent sign-in activity based on Microsoft Entra ID sign-in logs.
    It lists apps that have not been used for the specified number of days and apps that have no sign-in records.
    Use it to find candidates for review, cleanup, or decommissioning.

    Optionally, the report can be sent via email with CSV and/or Excel (xlsx) attachments containing the inactive and never-used applications.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachments exceed the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER Days
    Number of days without user logon to consider an application as inactive. Default is 90 days.

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

    .PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

    .PARAMETER BrandingAccentColor
    Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
    Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

    .PARAMETER BrandingTextColor
    Optional text color override (6-digit hex) for the report email template.
    Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Days without user logon"
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
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
                "DisplayName": "Create a file download link (upload report to storage)?",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
                }
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
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
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
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [int] $Days = 90,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "list-inactive-enterprise-applications",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string] $ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string] $StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string] $EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string] $BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string] $BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string] $BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string] $BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string] $BrandingTextColor,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
}
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
        exit
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Function Definitions
########################################################

#endregion

########################################################
#region     Connect Part
########################################################

Connect-RjRbGraph

# Get tenant information for the email report
$TenantDisplayName = "Unknown Tenant"
if ($EmailTo) {
    try {
        $tenantInfo = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "displayName"
        if ($tenantInfo -and $tenantInfo[0].displayName) {
            $TenantDisplayName = $tenantInfo[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

#endregion

########################################################
#region     Inactive Applications (last sign-in older than threshold)
########################################################

$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"

"## Inactive Applications (Last SignIn more than $Days days ago):"
""
[array]$UsedApps = @()
$inactiveApps = @()
try {
    Invoke-RjRbRestMethodGraph -Resource "/auditLogs/SignIns" -FollowPaging | Select-Object -Property appDisplayName, appId, createdDateTime | Group-Object -Property appId | ForEach-Object {
        $first = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1
        $UsedApps += Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
        if ($first.createdDateTime -le $lastSignInDate) {
            $app = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($app.Id)" -Method Patch -body @{ notes = $(($first.createdDateTime).ToString('o')) }
            $loginTime = New-TimeSpan -Start $first.createdDateTime -End (Get-Date)
            # Some apps seem to have no DisplayName...
            if ($app.appDisplayName) {
                "## $($app.appDisplayName): no logins for $($loginTime.Days) Days"
            }
            else {
                "## (AppId) $($app.appId): no logins for $($loginTime.Days) Days"
            }
            $inactiveApps += [PSCustomObject]@{
                AppDisplayName      = $(if ($app.appDisplayName) { $app.appDisplayName } else { "" })
                AppId               = $app.appId
                ServicePrincipalId  = $app.id
                LastSignIn          = $first.createdDateTime
                DaysSinceLastSignIn = [int]$loginTime.Days
            }
        }
    }
}
catch {
    Write-Error "Listing AuditLog or ServicePrincipals failed. Missing permissions? Error details: $($_)" -ErrorAction Stop
}

#endregion

########################################################
#region     Applications without any sign-in record
########################################################

""
"## Inactive Applications (No SignIn record exists in AuditLog):"
""

$neverUsedApps = @()

try {
    $AllApps = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -FollowPaging
    $unusedApps = (Compare-Object $AllApps $UsedApps).InputObject
    foreach ($app in $unusedApps) {
        # Some apps seem to have no DisplayName...
        if ($app.appDisplayName) {
            "## $($app.appDisplayName): no logins recorded in auditLog"
        }
        else {
            "## (AppId) $($app.appId): no logins recorded in auditLog"
        }
        $neverUsedApps += [PSCustomObject]@{
            AppDisplayName     = $(if ($app.appDisplayName) { $app.appDisplayName } else { "" })
            AppId              = $app.appId
            ServicePrincipalId = $app.id
        }
    }
}
catch {
    Write-Error "Listing ServicePrincipals failed. Missing permissions? Error details: $($_)" -ErrorAction Stop
}

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

$inactiveCount = ($inactiveApps | Measure-Object).Count
$neverUsedCount = ($neverUsedApps | Measure-Object).Count
$totalFound = $inactiveCount + $neverUsedCount
$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Inactive = "inactive-enterprise-apps.csv"
$fileName_NeverUsed = "never-used-enterprise-apps.csv"
$fileName_Xlsx = "inactive-enterprise-apps.xlsx"

if (($EmailTo -or $CreateDownloadLink) -and $totalFound -gt 0) {
    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "InactiveEnterpriseApps_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    if ($ReportFileFormat -ne 'XLSX only') {
        # Export inactive applications (last sign-in older than the threshold)
        $csvPath_Inactive = Join-Path $tempDir.FullName $fileName_Inactive
        $inactiveApps | Export-Csv -Path $csvPath_Inactive -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvPath_Inactive
        Write-Output "Exported inactive applications to: $csvPath_Inactive"

        # Export applications without any sign-in record (if any)
        if ($neverUsedCount -gt 0) {
            $csvPath_NeverUsed = Join-Path $tempDir.FullName $fileName_NeverUsed
            $neverUsedApps | Export-Csv -Path $csvPath_NeverUsed -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvPath_NeverUsed
            Write-Output "Exported never-used applications to: $csvPath_NeverUsed"
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet
        $xlsxPath = Join-Path $tempDir.FullName $fileName_Xlsx
        $workbookCoverSheet = [ordered]@{
            Title                                = 'Inactive Enterprise Applications'
            Generated                            = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'                    = $Version
            'Days threshold'                     = $Days
            'Inactive Applications'              = $inactiveCount
            'Applications Without Sign-in Record' = $neverUsedCount
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Inactive' = $inactiveApps; 'No Sign-in' = $neverUsedApps }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
        Write-Output "Exported applications workbook to: $xlsxPath"
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "Uploading report to storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No report files were generated - skipping report upload."
    }
}

#endregion

########################################################
#region     Send Email Report (if EmailTo is provided)
########################################################

$brandingMailParams = @{}
if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

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

This report lists enterprise applications in your tenant without recent sign-in activity based on the Microsoft Entra ID sign-in logs.

| Metric | Count |
|--------|-------|
| **Inactive applications (last sign-in more than $Days days ago)** | $inactiveCount |
| **Applications without any sign-in record** | $neverUsedCount |

**Inactivity threshold:** $Days days

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Inactive)**: Applications whose last sign-in is more than $Days days ago (CSV)" })
$(if ($ReportFileFormat -ne 'XLSX only' -and $neverUsedCount -gt 0) { "- **$($fileName_NeverUsed)**: Applications without any sign-in record in the audit log (CSV)" })
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
        if ($($reportFiles | Measure-Object).Count -gt 0) {
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

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $TenantDisplayName
                ReportVersion     = $Version
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $TenantDisplayName -ReportVersion $Version @brandingMailParams
            Write-Output "Email report sent successfully to: $EmailTo"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)"
        throw
    }
    finally {
        # Cleanup temporary files
        if ($reportFiles.Count -gt 0 -and $tempDir) {
            Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Verbose "Cleaned up temporary files"
        }
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

# Cleanup temporary files (covers the download-link-only case; the email path cleans up in its finally block)
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Verbose "Cleaned up temporary files"
}

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

#endregion
