<#
    .SYNOPSIS
    Report Intune devices without a primary user

    .DESCRIPTION
    Lists all Intune managed devices that have no primary user, with object ID, device ID, name, operating system and last sync, so shared or orphaned devices can be reviewed. The list can be limited by platform. Nothing is changed. The report can be sent by email or provided as a download link.

    .PARAMETER IncludeWindows
    Includes Windows devices.

    .PARAMETER IncludeMacOS
    Includes macOS devices.

    .PARAMETER IncludeIOS
    Includes iOS and iPadOS devices.

    .PARAMETER IncludeAndroid
    Includes Android devices.

    .PARAMETER IncludeOther
    Includes devices with any other operating system, such as Linux or ChromeOS.

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
            "IncludeWindows": {
                "DisplayName": "Include Windows devices?"
            },
            "IncludeMacOS": {
                "DisplayName": "Include macOS devices?"
            },
            "IncludeIOS": {
                "DisplayName": "Include iOS/iPadOS devices?"
            },
            "IncludeAndroid": {
                "DisplayName": "Include Android devices?"
            },
            "IncludeOther": {
                "DisplayName": "Include other devices?"
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