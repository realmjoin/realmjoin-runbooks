<#
    .SYNOPSIS
    Reports all managed devices in Intune that do not have a primary user assigned.
    .DESCRIPTION
    This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
    The output is a formatted table showing Object ID, Device ID, Display Name, Operating System, and Last Sync Date/Time for each device without a primary user.
    The report can be limited to specific platforms (Windows, macOS, iOS/iPadOS, Android, Other) via boolean parameters. By default, all platforms are included.

    Optionally, the report can be sent via email with CSV and/or Excel (xlsx) attachments containing detailed device information.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER IncludeWindows
    Include Windows devices in the report. Enabled by default.

    .PARAMETER IncludeMacOS
    Include macOS devices in the report. Enabled by default.

    .PARAMETER IncludeIOS
    Include iOS and iPadOS devices in the report. Enabled by default.

    .PARAMETER IncludeAndroid
    Include Android devices in the report. Enabled by default.

    .PARAMETER IncludeOther
    Include devices with any other operating system (e.g. Linux, ChromeOS) in the report. Enabled by default.

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
            "IncludeWindows": {
                "DisplayName": "Include Windows Devices"
            },
            "IncludeMacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "IncludeIOS": {
                "DisplayName": "Include iOS/iPadOS Devices"
            },
            "IncludeAndroid": {
                "DisplayName": "Include Android Devices"
            },
            "IncludeOther": {
                "DisplayName": "Include Other Devices (e.g. Linux, ChromeOS)"
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
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param (
    [bool]$IncludeWindows = $true,

    [bool]$IncludeMacOS = $true,

    [bool]$IncludeIOS = $true,

    [bool]$IncludeAndroid = $true,

    [bool]$IncludeOther = $true,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "devices-without-primary-user",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string]$BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.9.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "IncludeWindows: $IncludeWindows" -Verbose
Write-RjRbLog -Message "IncludeMacOS: $IncludeMacOS" -Verbose
Write-RjRbLog -Message "IncludeIOS: $IncludeIOS" -Verbose
Write-RjRbLog -Message "IncludeAndroid: $IncludeAndroid" -Verbose
Write-RjRbLog -Message "IncludeOther: $IncludeOther" -Verbose
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

####################################################################
#region Function Definitions
####################################################################

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

function Test-OsIncluded {
    <#
        .SYNOPSIS
        Checks whether a device's operating system is included by the platform filter parameters.

        .PARAMETER OperatingSystem
        The operatingSystem value of the managed device as reported by Intune.
    #>
    param(
        [string]$OperatingSystem
    )

    switch -Wildcard ($OperatingSystem) {
        "Windows*" { return $IncludeWindows }
        "macOS*" { return $IncludeMacOS }
        "iOS*" { return $IncludeIOS }
        "iPadOS*" { return $IncludeIOS }
        "Android*" { return $IncludeAndroid }
        default { return $IncludeOther }
    }
}

#endregion

####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

# Get tenant information for email report
$tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method Get
$TenantDisplayName = $tenantInfo.value[0].displayName

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

####################################################################
#region Get all devices without registered users
####################################################################

$enabledPlatforms = @(
    @{ Name = "Windows"; Enabled = $IncludeWindows },
    @{ Name = "macOS"; Enabled = $IncludeMacOS },
    @{ Name = "iOS/iPadOS"; Enabled = $IncludeIOS },
    @{ Name = "Android"; Enabled = $IncludeAndroid },
    @{ Name = "Other"; Enabled = $IncludeOther }
) | Where-Object { $_.Enabled } | ForEach-Object { $_.Name }

if (($enabledPlatforms | Measure-Object).Count -eq 0) {
    throw "All platform filters are disabled. Enable at least one platform (Windows, macOS, iOS/iPadOS, Android, Other) to generate a report."
}

Write-Output ""
Write-Output "Getting all managed devices and filter those without a primary user..."
Write-Output "Included platforms: $($enabledPlatforms -join ', ')"
Write-Output "Note: This may take a while depending on the number of devices in your tenant."

# Define the base URI for the Microsoft Graph API to retrieve managed devices and the properties to select.
$baseURI = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

$selectQuery = '?$select='
$selectProperties = "id,azureADDeviceId,lastSyncDateTime,deviceName,operatingSystem,userId"

$raw = @()
$uri = $baseURI + $selectQuery + $selectProperties

do {
    $response = Invoke-MgGraphRequest -Uri $uri -Method Get -ErrorAction Stop
    $raw += $response.value | Where-Object {
        # Filter devices where userId is null or empty and the platform is included
        [string]::IsNullOrEmpty($_.userId) -and (Test-OsIncluded -OperatingSystem $_.operatingSystem)
    }
    $uri = $response.'@odata.nextLink'
} while ($null -ne $uri)

#endregion

####################################################################
#region Output Devices Without Primary User
####################################################################

Write-Output "Prepared output for devices without a primary user..."
# Create a PSCustomObject with all devices without registered users, and prettify the output
$devicesWithoutPrimaryUser = $raw | ForEach-Object {
    [PSCustomObject]@{
        ObjectId         = $_.id
        DeviceId         = $_.azureADDeviceId
        DisplayName      = $_.deviceName
        OperatingSystem  = $_.operatingSystem
        LastSyncDateTime = $_.lastSyncDateTime
    }
}

Write-Output ""
Write-Output "Devices without a primary user:"
if ($($devicesWithoutPrimaryUser | Measure-Object).Count -gt 0) {
    $devicesWithoutPrimaryUser | Sort-Object DisplayName | Format-Table -AutoSize
}
else {
    Write-Output "No devices without a primary user were found."
}

#endregion

####################################################################
#region Report File Export (if needed for download link or email)
####################################################################

$totalDevices = ($devicesWithoutPrimaryUser | Measure-Object).Count
$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Details = "devices-without-primary-user.csv"
$fileName_DetailsXlsx = "devices-without-primary-user.xlsx"

if (($CreateDownloadLink -or $EmailTo) -and $totalDevices -gt 0) {
    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DevicesWithoutPrimaryUser_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    $sortedDevices = $devicesWithoutPrimaryUser | Sort-Object DisplayName

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvPath = Join-Path $tempDir.FullName $fileName_Details
        $sortedDevices | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvPath
        Write-Output "Exported devices to: $csvPath"
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir.FullName $fileName_DetailsXlsx
        $sortedDevices | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Devices"
        $reportFiles += $xlsxPath
        Write-Output "Exported devices to: $xlsxPath"
    }
}

#endregion

####################################################################
#region Upload / Download Link (if CreateDownloadLink is enabled)
####################################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($totalDevices -gt 0) {
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
        Write-Output "No devices without a primary user were found - skipping report upload."
    }
}

#endregion

####################################################################
#region Send Email Report (if EmailTo is provided)
####################################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

    if ($totalDevices -eq 0) {
        # No devices without primary user found - send positive message without attachments
        $markdownContent = @"
# Devices Without Primary User Report

## Summary

**No devices without primary users were found** in your tenant. This is a positive result indicating that all managed devices have proper user assignments.

**Included platforms:** $($enabledPlatforms -join ', ')

## What does this mean

- ✅ **Complete User Assignment**: All managed devices in Intune have a primary user assigned
- ✅ **Proper Device Enrollment**: Devices are correctly enrolled and associated with users
- ✅ **Good Device Management**: Your device inventory is well-maintained

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Devices Without Primary User Report - No Issues Found"
    }
    else {
        # Devices without primary user found - prepare detailed report (CSV was already exported above)
        $markdownContent = @"
# Devices Without Primary User Report

## Executive Summary

This report identifies **$($totalDevices) managed device(s)** in your Intune tenant that do not have a primary user assigned.

**Included platforms:** $($enabledPlatforms -join ', ')

## Impact & Implications

Devices without a primary user assignment can cause:

- **User Experience Issues**: Users may not see expected apps, settings, or policies
- **Policy Targeting Problems**: User-targeted policies won't apply correctly
- **License Assignment Issues**: Per-user licensing may not function properly
- **Security Concerns**: Unclear ownership and accountability for device activities
- **Reporting Gaps**: Incomplete user activity and compliance reporting

## Detailed Device Information

The attached CSV and Excel files contain the following information for each device:

| Column | Description |
|--------|-------------|
| **ObjectId** | Intune managed device object ID |
| **DeviceId** | Entra ID device ID |
| **DisplayName** | Device name in Intune |
| **OperatingSystem** | Operating system of the device |
| **LastSyncDateTime** | Last sync date and time with Intune |

## Recommended Actions

### Immediate Actions
1. **Review Device List**: Examine the attached files to identify affected devices
2. **Identify Device Ownership**: Determine which users should be assigned to each device
3. **Assign Primary Users**: Use Intune to assign primary users to devices where appropriate

### Assignment Methods
- **Intune Portal**: Manually assign users via the device properties page
- **Graph API**: Use Microsoft Graph API for bulk user assignments
- **Enrollment Policies**: Review and update enrollment policies to ensure user assignment during setup

### Shared Devices
For devices that are legitimately shared:
- Consider using **Shared Device Mode** for appropriate scenarios
- Implement **Multi-User Management** policies for shared workstations
- Document exceptions and justifications for devices without primary users

### Prevention Strategies
- **Enrollment Review**: Audit enrollment processes to ensure user assignment
- **Automated Workflows**: Implement automation to assign users during enrollment
- **Regular Monitoring**: Schedule this report to run periodically
- **Documentation**: Maintain clear guidelines for device enrollment and user assignment

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Details)**: Complete list of all devices without primary user assignment (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_DetailsXlsx)**: The same list as a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*

"@

        $emailSubject = "Devices Without Primary User Report - $totalDevices Device(s) Found"
    }

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        if ($($reportFiles | Measure-Object).Count -gt 0) {
            $markdownFallback = @"
# Devices Without Primary User Report

## Executive Summary

This report identifies **$($totalDevices) managed device(s)** in your Intune tenant that do not have a primary user assigned.

**Included platforms:** $($enabledPlatforms -join ', ')

## Data Files

- **$($fileName_DetailsXlsx)**: Formatted Excel workbook with the complete device list

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

####################################################################
#region Cleanup
####################################################################
# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

# Cleanup temporary files (covers the download-link-only case; the email path cleans up in its finally block)
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Verbose "Cleaned up temporary files"
}

#endregion