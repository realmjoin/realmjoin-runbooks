<#
    .SYNOPSIS
    List group ownerships for this user.

    .DESCRIPTION
    Lists Entra ID groups where the specified user is an owner. Outputs the group names and IDs.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER SendMail
    If enabled, the report is sent via email with the selected report file format(s) attached. Toggling this on reveals the recipient address and report file format fields.

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER EmailTo
    Recipient address or multiple comma-separated addresses for the email report. Only used when SendMail is enabled.

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

    .PARAMETER CreateDownloadLink
    If enabled, the report files (CSV and Excel) are uploaded to an Azure Storage Account and time-limited download links are returned in the output.

    .PARAMETER ContainerName
    Storage container name used for the upload.

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account.

    .PARAMETER StorageAccountName
    Storage account name used for the upload.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "SendMail": {
                "DisplayName": "Send the report via email?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo", "ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo", "ReportFileFormat"]
                            }
                        }
                    ]
                }
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a file download link (upload report to storage)?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload report and return a download link",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not create a download link",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["ReportFileFormat"]
                            }
                        }
                    ]
                }
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
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)",
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
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,

    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

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

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "user-group-ownerandmemberships",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

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
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
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

# A recipient and a configured sender are required to send an email report
if ($SendMail) {
    if (-not $EmailTo) {
        throw "A recipient email address (EmailTo) is required when 'Send the report via email' is enabled."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
        throw "The sender email address (EmailFrom) needs to be configured in the runbook customization."
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
#region     Connect and Initialize
########################################################

Connect-RjRbGraph

if ($CreateDownloadLink) {
    try {
        Write-Output "Connecting to Azure (RealmJoin)..."
        Connect-RjRbAzAccount
    }
    catch {
        Write-Error "Failed to connect to Azure (RealmJoin): $_"
        throw $_
    }
}

#endregion

########################################################
#region     Main Code
########################################################

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/ownedObjects/microsoft.graph.group/" -FollowPaging

# Build a structured report object per owned group (used for console output, CSV file, and email)
$reportData = @()
if ($OwnedGroups) {
    $reportData = foreach ($OwnedGroup in $OwnedGroups) {
        $groupType = if ($OwnedGroup.groupTypes -contains "Unified") {
            "M365"
        } elseif ($OwnedGroup.securityEnabled -and -not $OwnedGroup.mailEnabled) {
            "Security"
        } elseif ($OwnedGroup.mailEnabled) {
            "Distribution"
        } else {
            "Other"
        }

        [PSCustomObject]@{
            DisplayName = $OwnedGroup.displayName
            ID          = $OwnedGroup.id
            Type        = $groupType
        }
    }
    $reportData = @($reportData)
}

"## Listing group ownerships for '$($User.UserPrincipalName)':"
if ($reportData.Count -gt 0) {
    foreach ($item in $reportData) {
        "## Group '$($item.DisplayName)' with id '$($item.ID)'"
    }
} else {
    "## User is not an owner of any groups."
}

#endregion

########################################################
#region     Output/Export, Upload and Email
########################################################

# The report files are only needed when they will be uploaded and/or attached to an email
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($SendMail -or $CreateDownloadLink) -and $reportData.Count -gt 0) {
    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFileName = "group-ownerships_$($User.UserPrincipalName)_$(Get-Date -Format 'yyyyMMdd').csv"
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
        $reportData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported $($reportData.Count) groups to CSV: $csvFilePath" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFileName = "group-ownerships_$($User.UserPrincipalName)_$(Get-Date -Format 'yyyyMMdd').xlsx"
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $xlsxFileName
        $reportData | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Group Ownerships"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported $($reportData.Count) groups to XLSX: $xlsxFilePath" -Verbose
    }
}
elseif (($SendMail -or $CreateDownloadLink) -and $reportData.Count -eq 0) {
    Write-Output ""
    Write-Output "## No groups found - skipping report export, upload and email."
}

#region Upload / Download Link (optional)
##############################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $reportFiles `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    Write-Output "## Report uploaded to storage account."
    foreach ($uploadResult in $uploadResults) {
        Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Upload / Download Link

#region Send Email Report (optional)
##############################

if ($SendMail -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Preparing email report to send to '$($EmailTo)'..."

    # Resolve tenant display name for the report header
    $tenantDisplayName = "Unknown Tenant"
    try {
        $tenantInfo = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "displayName"
        if ($tenantInfo -and $tenantInfo[0].displayName) {
            $tenantDisplayName = $tenantInfo[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }

    $subject = "Group Ownerships - $($User.UserPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownContent = @"
# Group Ownerships Report

**User:** $($User.UserPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups owned by the user: **$($reportData.Count)**

The report file(s) are attached for your review.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# Group Ownerships Report

**User:** $($User.UserPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups owned by the user: **$($reportData.Count)**

- **$($xlsxFileName)**: Formatted Excel workbook with the complete report

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $guardParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $subject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
            Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

#endregion Send Email Report

#endregion

########################################################
#region     Cleanup
########################################################
# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not remove temporary report file '$reportFilePath': $_"
        }
    }
}

if ($CreateDownloadLink) {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}

#endregion