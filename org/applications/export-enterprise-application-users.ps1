<#
    .SYNOPSIS
    Export a report of all (enterprise) application owners and users

    .DESCRIPTION
    This runbook exports a report of enterprise applications (or all service principals) including owners and assigned users or groups.
    By default, the generated report files are uploaded to an Azure Storage Account and time-limited download links are returned.
    Optionally, the report can be sent via email with CSV and/or Excel (xlsx) attachments.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER entAppsOnly
    Determines whether to export only enterprise applications (final value: true) or all service principals/applications (final value: false).

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Enabled by default.

    .PARAMETER ContainerName
    Storage container name used for the upload.

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account.

    .PARAMETER StorageAccountName
    Storage account name used for the upload.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires.

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
            "entAppsOnly": {
                "DisplayName": "Scope",
                "SelectSimple": {
                    "List only Enterprise Apps": true,
                    "List all Service Principals / Apps": false
                }
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
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "List only Enterprise Apps" } )]
    [bool] $entAppsOnly = $true,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',
    [bool] $CreateDownloadLink = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string] $BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string] $BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string] $BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string] $BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string] $BrandingTextColor,
    [string] $EmailTo,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region RJ Log Part
#
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "entAppsOnly: $entAppsOnly" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
}

#endregion RJ Log Part

############################################################
#region Parameter Validation
#
############################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
    exit
    }
}

#endregion Parameter Validation

############################################################
#region Function Definitions
#
############################################################

#endregion Function Definitions

############################################################
#region Connect Part
#
############################################################

Connect-RjRbGraph
Connect-RjRbAzAccount

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

#endregion Connect Part

############################################################
#region Main Part
#
############################################################

$brandingMailParams = @{}

try {

    #region Configuration
    ##############################

    if (-not $ContainerName) {
        $ContainerName = "enterprise-apps-users"
    }

    # Storage account configuration is only required when a download link is requested
    if ($CreateDownloadLink) {
        # Configuration import - fallback to Az Automation Variable
        if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
            $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
            #if (-not $processConfigRaw) {
            ## production default - use this as template to create the Az. Automation Variable "SettingsExports"
            #    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings-org-policies-export.json"
            #    $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL
            #    $processConfigRaw = $webResult.Content        ## staging default
            #}
            # Write-RjRbDebug "Process Config URL is $($processConfigURL)"

            # "Getting Process configuration"
            $processConfig = $processConfigRaw | ConvertFrom-Json

            if (-not $ResourceGroupName) {
                $ResourceGroupName = $processConfig.exportResourceGroupName
            }

            if (-not $StorageAccountName) {
                $StorageAccountName = $processConfig.exportStorAccountName
            }
        }

        if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
            "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
            "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
            ""
            "## Configure the following attributes:"
            "## - EntAppsReport.ResourceGroup"
            "## - EntAppsReport.StorageAccount.Name"
            ""
            "## Stopping execution."
            throw "Missing Storage Account Configuration."
        }
    }

    #endregion Configuration

    #region Data Collection
    ##############################

    $invokeParams = @{
        resource = "/servicePrincipals"
    }

    if ($entAppsOnly) {
        $invokeParams += @{
            OdFilter = "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')"
        }
    }
    # Get Ent. Apps / Service Principals
    $servicePrincipals = Invoke-RjRbRestMethodGraph @invokeParams

    #endregion Data Collection

    #region Report Data
    ##############################

    $reportData = @($servicePrincipals | ForEach-Object {
            $AppId = $_.appId
            $AppDisplayName = $_.displayName
            $AccountEnabled = $_.accountEnabled
            $HideApp = $_.tags -contains "hideapp"
            $AssignmentRequired = $_.appRoleAssignmentRequired

            if ($_.notes) {
                $Notes = [string]::join(" ", ($_.notes.Split("`n") -replace (';', ',')))
            }
            else {
                $Notes = ""
            }

            # Get Owners
            $owners = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($_.id)/owners"
            if ($owners) {
                $owners | ForEach-Object {
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Owner"
                        PrincipalType      = "User"
                        PrincipalId        = $_.userPrincipalName
                        Notes              = $Notes
                    }
                }
            }
            else {
                # Make sure to list apps missing an owner
                [PSCustomObject]@{
                    AppId              = $AppId
                    AppDisplayName     = $AppDisplayName
                    AccountEnabled     = $AccountEnabled
                    HideApp            = $HideApp
                    AssignmentRequired = $AssignmentRequired
                    PrincipalRole      = "Owner"
                    PrincipalType      = "User"
                    PrincipalId        = ""
                    Notes              = $Notes
                }
            }

            # Get App Role assignments
            $users = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($_.id)/appRoleAssignedTo"
            $users | ForEach-Object {
                if ($_.principalType -eq "User") {
                    $userobject = Invoke-RjRbRestMethodGraph -Resource "/users/$($_.principalId)"
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "User"
                        PrincipalId        = $userobject.userPrincipalName
                        Notes              = $Notes
                    }
                }
                elseif ($_.principalType -eq "Group") {
                    $groupobject = Invoke-RjRbRestMethodGraph -Resource "/groups/$($_.principalId)"
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "Group"
                        PrincipalId        = "$($groupobject.mailNickname) ($($groupobject.displayName))"
                        Notes              = $Notes
                    }
                }
                elseif ($_.principalType -eq "ServicePrincipal") {
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "ServicePrincipal"
                        PrincipalId        = $_.principalId
                        Notes              = $Notes
                    }
                }
            }
        })

    $totalRows = $reportData.Count
    $appCount = ($servicePrincipals | Measure-Object).Count

    #endregion Report Data

    #region Report File Export
    ##############################

    $reportFiles = @()
    $csvPath = $null
    $xlsxPath = $null
    $fileNameCsv = "enterpriseApps.csv"
    $fileNameXlsx = "enterpriseApps.xlsx"

    if (($EmailTo -or $CreateDownloadLink) -and $totalRows -gt 0) {
        if ($ReportFileFormat -ne 'XLSX only') {
            $csvPath = Join-Path -Path $((Get-Location).Path) -ChildPath $fileNameCsv
            $reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvPath
            Write-Output "Exported $totalRows rows to: $csvPath"
        }

        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxPath = Join-Path -Path $((Get-Location).Path) -ChildPath $fileNameXlsx
            $reportData | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Enterprise App Users"
            $reportFiles += $xlsxPath
            Write-Output "Exported $totalRows rows to: $xlsxPath"
        }
    }
    elseif (($EmailTo -or $CreateDownloadLink) -and $totalRows -eq 0) {
        Write-Output "## No report data found - no report file to send or upload."
    }
    else {
        Write-Output "## Neither an email recipient (EmailTo) nor a download link (CreateDownloadLink) was requested - no report files are generated."
        Write-Output "## Report data ($totalRows rows):"
        $reportData | Format-Table -AutoSize | Out-String | Write-Output
    }

    #endregion Report File Export

    #region Upload
    ##############################

    if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        "## App Owner/User List Export created."
        foreach ($uploadResult in $uploadResults) {
            "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String
        }
    }

    #endregion Upload

    #region Send Email Report
    ##############################

    if ($EmailTo -and $reportFiles.Count -gt 0) {
        Write-Output ""
        Write-Output "## Preparing email report to send to '$($EmailTo)'..."

        $scopeDescription = if ($entAppsOnly) { "Enterprise Applications" } else { "All Service Principals / Applications" }

        $emailSubject = "Enterprise Application Users Report - $(Get-Date -Format 'yyyy-MM-dd')"

        $markdownContent = @"
# Enterprise Application Users Report

**Scope:** $scopeDescription
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Applications / service principals: **$appCount**
- Report rows (owners and assignments): **$totalRows**

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileNameCsv)**: Complete list of application owners and assigned users/groups (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileNameXlsx)**: The same list as a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $markdownFallback = @"
# Enterprise Application Users Report

**Scope:** $scopeDescription
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Applications / service principals: **$appCount**
- Report rows (owners and assignments): **$totalRows**

## Data Files

- **$($fileNameXlsx)**: Formatted Excel workbook with the complete report

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        try {
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
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)"
            throw
        }
    }

    #endregion Send Email Report

    Write-Output ""
    Write-Output "Done!"

}
catch {
    throw $_
}
finally {
    #region Cleanup
    ##############################

    # Remove the downloaded branding images, if any were used.
    foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
            Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
        }
    }

    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null

    #endregion Cleanup
}

#endregion Main Part
