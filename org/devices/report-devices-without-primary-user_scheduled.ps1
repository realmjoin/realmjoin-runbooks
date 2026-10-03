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

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "IncludeOther",
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
    [bool]$IncludeWindows = $true,

    [bool]$IncludeMacOS = $true,

    [bool]$IncludeIOS = $true,

    [bool]$IncludeAndroid = $true,

    [bool]$IncludeOther = $true,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "devices-without-primary-user",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

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

    [bool]$SendEmailReport = $false,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.10.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IncludeWindows: $IncludeWindows" -Verbose
Write-RjRbLog -Message "IncludeMacOS: $IncludeMacOS" -Verbose
Write-RjRbLog -Message "IncludeIOS: $IncludeIOS" -Verbose
Write-RjRbLog -Message "IncludeAndroid: $IncludeAndroid" -Verbose
Write-RjRbLog -Message "IncludeOther: $IncludeOther" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose

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

# At least one platform has to be evaluated
$enabledPlatforms = @(@(
        @{ Name = "Windows"; Enabled = $IncludeWindows },
        @{ Name = "macOS"; Enabled = $IncludeMacOS },
        @{ Name = "iOS/iPadOS"; Enabled = $IncludeIOS },
        @{ Name = "Android"; Enabled = $IncludeAndroid },
        @{ Name = "Other"; Enabled = $IncludeOther }
    ) | Where-Object { $_.Enabled } | ForEach-Object { $_.Name })

if ($enabledPlatforms.Count -eq 0) {
    Write-Error "All platform filters are disabled. Enable at least one platform (Windows, macOS, iOS/iPadOS, Android, Other) to generate a report." -ErrorAction Continue
    throw "No platform selected"
}

Write-Output "Included platforms: $($enabledPlatforms -join ', ')"
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

function Get-PlatformLabel {
    <#
        .SYNOPSIS
        Maps the operatingSystem value of a managed device to the platform label of the platform filters.

        .PARAMETER OperatingSystem
        The operatingSystem value of the managed device as reported by Intune.
    #>
    param(
        [string]$OperatingSystem
    )

    switch -Wildcard ($OperatingSystem) {
        "Windows*" { return "Windows" }
        "macOS*" { return "macOS" }
        "iOS*" { return "iOS/iPadOS" }
        "iPadOS*" { return "iOS/iPadOS" }
        "Android*" { return "Android" }
        default { return "Other" }
    }
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

    return ($enabledPlatforms -contains (Get-PlatformLabel -OperatingSystem $OperatingSystem))
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

# Tenant display name for the email (needs Organization.Read.All)
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
Write-Output "Retrieving all managed devices. This may take a while in large tenants."

# Only the properties the report needs; the primary user and the platform are evaluated locally.
$devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,azureADDeviceId,lastSyncDateTime,deviceName,operatingSystem,userId"

try {
    $allDevices = @(Get-GraphPagedResult -Uri $devicesUri)
}
catch {
    Write-Error "Failed to retrieve the Intune managed devices from Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve the Intune device inventory"
}

Write-Output "Retrieved $($allDevices.Count) managed device(s)."
Write-RjRbLog -Message "Managed devices retrieved: $($allDevices.Count)" -Verbose

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Devices without a primary user on one of the selected platforms, sorted by name
$devicesWithoutPrimaryUser = @($allDevices | Where-Object {
        [string]::IsNullOrEmpty($_.userId) -and (Test-OsIncluded -OperatingSystem $_.operatingSystem)
    } | ForEach-Object {
        [PSCustomObject]@{
            ObjectId         = $_.id
            DeviceId         = $_.azureADDeviceId
            DisplayName      = $_.deviceName
            OperatingSystem  = $_.operatingSystem
            LastSyncDateTime = $_.lastSyncDateTime
        }
    } | Sort-Object -Property DisplayName)

$totalDevices = $devicesWithoutPrimaryUser.Count

$platformCounts = [ordered]@{}
foreach ($platform in $enabledPlatforms) { $platformCounts[$platform] = 0 }
foreach ($device in $devicesWithoutPrimaryUser) {
    $platformLabel = Get-PlatformLabel -OperatingSystem $device.OperatingSystem
    if ($platformCounts.Contains($platformLabel)) { $platformCounts[$platformLabel]++ }
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Managed devices retrieved: $($allDevices.Count)"
Write-Output "Devices without a primary user: $totalDevices"
foreach ($platform in $platformCounts.Keys) {
    Write-Output "  $($platform): $($platformCounts[$platform])"
}
Write-RjRbLog -Message "Devices without a primary user: $totalDevices" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFile = $null
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DevicesWithoutPrimaryUser_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$csvFileName = "devices-without-primary-user.csv"
$xlsxFileName = "devices-without-primary-user.xlsx"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $totalDevices -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFile = Join-Path $tempDir $csvFileName
        $devicesWithoutPrimaryUser | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFile
        Write-RjRbLog -Message "Exported $totalDevices row(s) to CSV: $csvFile" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFile = Join-Path $tempDir $xlsxFileName
        $devicesWithoutPrimaryUser | Export-RjRbXlsx -Path $xlsxFile -WorksheetName 'Devices without primary user'
        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $totalDevices row(s) to XLSX: $xlsxFile" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($totalDevices -eq 0) {
    Write-RjRbLog -Message "No devices without a primary user - skipping the report file export" -Verbose
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
        Write-Output "No devices without a primary user were found - skipping the upload."
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

    if ($totalDevices -eq 0) {
        # No devices without primary user found - send a positive message without attachments
        $markdownContent = @"
# Devices Without Primary User Report

## Summary

**No devices without primary users were found** in your tenant. This is a positive result indicating that all managed devices have proper user assignments.

**Included platforms:** $($enabledPlatforms -join ', ')

## What does this mean

- **Complete User Assignment**: All managed devices in Intune have a primary user assigned
- **Proper Device Enrollment**: Devices are correctly enrolled and associated with users
- **Good Device Management**: Your device inventory is well-maintained

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Devices Without Primary User Report - No Issues Found"
    }
    else {
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

The attached report file(s) contain the following information for each device:

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

$(if ($csvFile) { "- **$($csvFileName)**: Complete list of all devices without primary user assignment (CSV)" })
$(if ($xlsxFile) { "- **$($xlsxFileName)**: The same list as a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*

"@

        $emailSubject = "Devices Without Primary User Report - $totalDevices Device(s) Found"
    }

    $markdownFallback = @"
# Devices Without Primary User Report

## Executive Summary

This report identifies **$($totalDevices) managed device(s)** in your Intune tenant that do not have a primary user assigned.

**Included platforms:** $($enabledPlatforms -join ', ')

## Data Files

- **$($xlsxFileName)**: Formatted Excel workbook with the complete device list

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
        elseif ($reportFiles.Count -gt 0) {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
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

$summaryValues = [ordered]@{
    "Managed devices retrieved"    = $allDevices.Count
    "Devices without primary user" = $totalDevices
}
foreach ($platform in $platformCounts.Keys) {
    $summaryValues["$platform without primary user"] = $platformCounts[$platform]
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($totalDevices -gt 0) {
    $deviceRows = @($devicesWithoutPrimaryUser | Select-Object -Property DisplayName, OperatingSystem, LastSyncDateTime, DeviceId, ObjectId)
    Write-Output "$totalDevices device(s) without a primary user"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Devices without primary user" })
    Write-Output $deviceRows
}
else {
    Write-Output "No devices without a primary user were found."
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
