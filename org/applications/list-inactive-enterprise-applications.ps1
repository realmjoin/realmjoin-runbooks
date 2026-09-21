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
                "DisplayName": "Recipient email address(es)"
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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

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

$Version = "1.4.0"
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

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
    #>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect Part
########################################################

Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information for the email report
$TenantDisplayName = "Unknown Tenant"
if ($EmailTo) {
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($tenantInfo.value -and ($tenantInfo.value | Measure-Object).Count -gt 0 -and $tenantInfo.value[0].displayName) {
            $TenantDisplayName = $tenantInfo.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

#endregion

########################################################
#region     Service Principals and Sign-in Activity
########################################################

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

#endregion

########################################################
#region     Output
########################################################

"## Inactive Applications (Last SignIn more than $Days days ago):"
""
if (($inactiveApps | Measure-Object).Count -eq 0) {
    "## None"
}
else {
    foreach ($app in $inactiveApps) {
        # Some apps seem to have no DisplayName...
        if ($app.AppDisplayName) {
            "## $($app.AppDisplayName): no logins for $($app.DaysSinceLastSignIn) Days"
        }
        else {
            "## (AppId) $($app.AppId): no logins for $($app.DaysSinceLastSignIn) Days"
        }
    }
}

""
"## Inactive Applications (No SignIn recorded):"
""
if (($neverUsedApps | Measure-Object).Count -eq 0) {
    "## None"
}
else {
    foreach ($app in $neverUsedApps) {
        # Some apps seem to have no DisplayName...
        if ($app.AppDisplayName) {
            "## $($app.AppDisplayName): no sign-in recorded"
        }
        else {
            "## (AppId) $($app.AppId): no sign-in recorded"
        }
    }
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

This report lists enterprise applications in your tenant without recent sign-in activity, based on the Microsoft Entra service principal sign-in activity report.

| Metric | Count |
|--------|-------|
| **Inactive applications (last sign-in more than $Days days ago)** | $inactiveCount |
| **Applications without any sign-in record** | $neverUsedCount |

**Inactivity threshold:** $Days days

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Inactive)**: Applications whose last sign-in is more than $Days days ago (CSV)" })
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

            # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
            $guardParams = @{
                EmailFrom              = $EmailFrom
                EmailTo                = $EmailTo
                Subject                = $emailSubject
                MarkdownContent        = $markdownContent
                TenantDisplayName      = $TenantDisplayName
                ReportVersion          = $Version
                UseNativeGraphRequest  = $true
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
            Write-Output "Email report sent successfully to: $EmailTo"
        }
        else {
            # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
            Send-RjRbReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $TenantDisplayName -ReportVersion $Version -UseNativeGraphRequest @brandingMailParams
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
