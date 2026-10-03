<#
	.SYNOPSIS
	Report users with more than five registered devices

	.DESCRIPTION
	Finds users who have more than five devices registered in Entra ID. The report has a summary and a detailed list of their devices, including whether each device is managed by Intune and compliant. Useful to spot leftover registrations before device limits are hit. The report can be sent by email or provided as a download link.

	.PARAMETER IntuneOnlyDevices
	Counts only devices that are also managed by Intune, so unmanaged registrations are ignored.

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
			"IntuneOnlyDevices": {
				"DisplayName": "Only count devices managed by Intune?"
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
				"Select": {
					"Options": [
						{ "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
						{ "Display": "CSV only", "ParameterValue": "CSV only" },
						{ "Display": "XLSX only", "ParameterValue": "XLSX only" }
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
				"DisplayAfter": "IntuneOnlyDevices",
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
    [bool]$IntuneOnlyDevices = $false,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "users-with-more-than-5-devices",

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

$Version = "1.12.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IntuneOnlyDevices: $IntuneOnlyDevices" -Verbose
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

$scopeText = if ($IntuneOnlyDevices) { 'Only devices present in Intune' } else { 'All Entra ID devices' }
Write-Output "Scope: $scopeText"
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

# Tenant display name for the email subject and body (needs Organization.Read.All)
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
Write-Output "Data Collection"
Write-Output "---------------------"

Write-Output "Querying devices..."
Write-Output "  Note: Depending on the number of devices in the tenant, this process can take several minutes!"
$property = 'id,deviceId,displayName,isCompliant,registeredUsers'

$uri = "https://graph.microsoft.com/v1.0/devices?`$select=$property&`$expand=registeredUsers"
$AllDevices_BasedOnUsers = @(Get-GraphPagedResult -Uri $uri)
$entraDeviceCount = $AllDevices_BasedOnUsers.Count

Write-Output "  Retrieved $entraDeviceCount devices from the tenant."

# Retrieve all Intune managed devices to determine Intune presence per device (and to filter, if requested)
Write-Output "Querying Intune managed devices..."
$intuneManagedDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=azureADDeviceId")
$intuneDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($managedDevice in $intuneManagedDevices) {
    if ($managedDevice.azureADDeviceId) {
        [void]$intuneDeviceIds.Add([string]$managedDevice.azureADDeviceId)
    }
}
Write-Output "  Retrieved $($intuneManagedDevices.Count) managed devices from Intune."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Data Processing"
Write-Output "---------------------"

if ($IntuneOnlyDevices) {
    $AllDevices_BasedOnUsers = @($AllDevices_BasedOnUsers | Where-Object { $_.deviceId -and $intuneDeviceIds.Contains([string]$_.deviceId) })
    Write-Output "Only devices present in Intune are considered: $($AllDevices_BasedOnUsers.Count) devices remain."
}
$consideredDeviceCount = $AllDevices_BasedOnUsers.Count

$raw = $AllDevices_BasedOnUsers | Where-Object { $_.RegisteredUsers.Count -gt 0 } | Group-Object { $_.RegisteredUsers.Id } | Where-Object Count -GT 5

# One row per user (user ID, UPN and number of devices) and one row per device of these users
$Output = @()
$detailedOutput = @()

foreach ($group in $raw) {
    $objectId = $group.Name
    $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
    $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName

    $Output += [PSCustomObject]@{
        ObjectId    = $objectId
        DisplayName = $displayName
        UPN         = $upn
        DeviceCount = $group.Count
    }

    foreach ($device in $group.Group) {
        $deviceEntry = [ordered]@{
            UserObjectId    = $objectId
            UserDisplayName = $displayName
            UserUPN         = $upn
            DeviceObjectId  = $device.Id
            EntraIDDeviceID = $device.deviceId
            DeviceName      = if ($device.DisplayName) { $device.DisplayName } else { "N/A" }
        }
        if (-not $IntuneOnlyDevices) {
            $deviceEntry.InIntune = if ($device.deviceId -and $intuneDeviceIds.Contains([string]$device.deviceId)) { "yes" } else { "no" }
        }
        $deviceEntry.Compliant = if ($null -eq $device.isCompliant) { "unknown" } elseif ($device.isCompliant) { "yes" } else { "no" }
        $detailedOutput += [PSCustomObject]$deviceEntry
    }
}

$summaryOutput = @($Output | Sort-Object DeviceCount -Descending)
$detailedOutput = @($detailedOutput | Sort-Object UserUPN, DeviceName)
$totalUsers = $summaryOutput.Count
$totalDevices = $detailedOutput.Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Tenant: $tenantDisplayName"
Write-Output "Scope: $scopeText"
Write-Output "Devices considered: $consideredDeviceCount"
if ($totalUsers -eq 0) {
    Write-Output "No users found with more than five devices."
}
else {
    Write-Output "Users with more than five devices: $totalUsers"
    Write-Output "Devices of these users: $totalDevices"
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$xlsxFile = $null
$tempDir = $null
$fileName_Summary = "UsersWithMoreThan5Devices_Summary.csv"
$fileName_Details = "UsersWithMoreThan5Devices_Details.csv"
$fileName_Workbook = "UsersWithMoreThan5Devices.xlsx"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $totalUsers -gt 0) {
    Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing report file export" -Verbose

    # Create temporary directory for report files
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "UsersWithMultipleDevicesReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        # Export summary to CSV
        $csvFile = Join-Path $tempDir $fileName_Summary
        $summaryOutput | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-RjRbLog -Message "Exported summary data to: $csvFile" -Verbose
        $reportFiles += $csvFile

        # Export detailed device list to CSV
        $detailedCsvFile = Join-Path $tempDir $fileName_Details
        $detailedOutput | Export-Csv -Path $detailedCsvFile -NoTypeInformation -Encoding UTF8
        Write-RjRbLog -Message "Exported detailed device data to: $detailedCsvFile" -Verbose
        $reportFiles += $detailedCsvFile
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet.
        # The worksheets carry the names of the matching Output Data tables.
        # The InIntune and Compliant columns are highlighted green/red; when IntuneOnlyDevices omits the InIntune column, its rules are skipped.
        $xlsxFile = Join-Path $tempDir $fileName_Workbook
        $workbookCoverSheet = [ordered]@{
            Title                = 'Users with More Than 5 Devices'
            Tenant               = $tenantDisplayName
            Generated            = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'    = $Version
            Scope                = $scopeText
            'Users (>5 devices)' = $totalUsers
            'Device entries'     = $totalDevices
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Users' = $summaryOutput; 'Devices' = $detailedOutput }) -Path $xlsxFile -CoverSheet $workbookCoverSheet -HighlightRules @(
            @{ Column = 'InIntune'; Value = 'yes'; Color = 'Green' }
            @{ Column = 'InIntune'; Value = 'no'; Color = 'Red' }
            @{ Column = 'Compliant'; Value = 'yes'; Color = 'Green' }
            @{ Column = 'Compliant'; Value = 'no'; Color = 'Red' }
        )
        Write-RjRbLog -Message "Exported summary and detailed data to: $xlsxFile" -Verbose
        $reportFiles += $xlsxFile
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($totalUsers -eq 0) {
    Write-RjRbLog -Message "No users with more than 5 devices - skipping the report file export" -Verbose
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
        Write-Output "No users with more than five devices were found - skipping the upload."
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

    if ($totalUsers -eq 0) {
        # No users found - send email without attachments
        Write-RjRbLog -Message "No users found with more than 5 devices - sending notification email" -Verbose

        $markdownContent = @"
# Users with More Than 5 Devices Report

## Summary

**Good news:** No users were found with more than 5 devices registered in Entra ID.
$(if ($IntuneOnlyDevices) { "`n**Scope:** Only devices present in Intune were considered for this report.`n" })

This indicates:
- Users are following device management policies
- No excessive device registrations detected
- Healthy device distribution across the organization

## Report Details

| Metric | Value |
|--------|-------|
| **Users with >5 Devices** | 0 |
| **Report Date** | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |
| **Tenant** | $($tenantDisplayName) |

---

*This email was automatically generated. Please do not reply to this email.*

"@

        $emailSubject = "Users with More Than 5 Devices Report - No Issues Found - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"
    }
    else {
        # Users found - send detailed report (report files were already exported above)
        Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing detailed report" -Verbose

        # Calculate statistics
        $avgDevicesPerUser = if ($totalUsers -gt 0) { [math]::Round($totalDevices / $totalUsers, 2) } else { 0 }
        $maxDevices = ($summaryOutput | Measure-Object -Property DeviceCount -Maximum).Maximum
        $minDevices = ($summaryOutput | Measure-Object -Property DeviceCount -Minimum).Minimum

        # Create markdown content for email with detailed findings
        $markdownContent = @"
# Users with More Than 5 Devices Report

This report identifies users who have more than 5 devices registered in Entra ID.
$(if ($IntuneOnlyDevices) { "`n**Scope:** Only devices present in Intune were considered for this report.`n" })

## Summary Statistics

Based on the filtered data (users with >5 devices), the following statistics were calculated.
Note that these statistics only consider users who meet the >5 devices criteria.

| Metric | Value |
|--------|-------|
| **Total Users with >5 Devices** | $totalUsers |
| **Total Devices** | $totalDevices |
| **Average Devices per User** | $avgDevicesPerUser |
| **Maximum Devices (Single User)** | $maxDevices |
| **Minimum Devices** | $minDevices |

## Top 20 Users by Device Count

| User Display Name | User Principal Name | Device Count |
|-------------------|---------------------|--------------|
$(
    ($summaryOutput | Select-Object -First 20 | ForEach-Object {
        "| $($_.DisplayName) | $($_.UPN) | $($_.DeviceCount) |"
    }) -join "`n"
)

## Report Details

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Summary)**: Summary of $($totalUsers) users with their device counts (CSV)" })
$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Details)**: Detailed device information for each user, $($totalDevices) device entries (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_Workbook)**: Both datasets as separate worksheets (`"Users`" and `"Devices`") in an Excel workbook" })

## Recommendations

### Device Management Best Practices

**Review Device Assignments:**
- Users with many devices may have old/inactive devices registered
- Consider implementing a device cleanup policy
- Review if all devices are actively used

**Security Considerations:**
- Multiple devices increase the attack surface
- Ensure all devices comply with security policies
- Verify that unused devices are properly decommissioned

**Compliance & Licensing:**
- Check if device counts align with licensing agreements
- Ensure proper MDM/MAM coverage across all devices
- Consider user education on device management

### Suggested Actions

1. **Contact High-Device-Count Users:**
   - Verify all registered devices are legitimate
   - Request removal of unused/old devices
   - Provide guidance on device management

2. **Implement Device Limits:**
   - Consider setting maximum device limits per user
   - Create automated workflows for device approval
   - Establish regular device audits

3. **Monitor Trends:**
   - Track device registration patterns
   - Identify users who frequently exceed limits
   - Adjust policies based on organizational needs

## Data Export Information

The attached file(s) contain:
- **Summary / Users:** User Object ID, Display Name, UPN, and Device Count
- **Details / Devices:** Complete device list for each user including the device object ID, the Entra ID device ID and the device name$(if (-not $IntuneOnlyDevices) { ", plus an ""InIntune"" column indicating whether the device is present in Intune" }), plus a ""Compliant"" column indicating the device compliance state (yes/no/unknown)
$(if ($ReportFileFormat -ne 'CSV only') { "- **Excel Workbook:** Both datasets in one file, one worksheet each" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Users with More Than 5 Devices Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"
    }

    $markdownFallback = @"
# Users with More Than 5 Devices Report

This report identifies users who have more than 5 devices registered in Entra ID.
$(if ($IntuneOnlyDevices) { "`n**Scope:** Only devices present in Intune were considered for this report.`n" })

## Summary Statistics

| Metric | Value |
|--------|-------|
| **Total Users with >5 Devices** | $totalUsers |
| **Total Devices** | $totalDevices |

## Report Details

- **$($fileName_Workbook)**: Excel workbook with both datasets as separate worksheets (`"Users`" and `"Devices`")

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Choose a delivery with a download link to obtain the raw CSV files.

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
            # Both formats attached; the built-in size guard falls back to the workbook alone if the CSV files make the set too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
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
    "Scope"                             = $scopeText
    "Entra ID devices"                  = $entraDeviceCount
    "Intune managed devices"            = $intuneManagedDevices.Count
    "Devices considered"                = $consideredDeviceCount
    "Users with more than five devices" = $totalUsers
    "Devices of these users"            = $totalDevices
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = "$($summaryValues[$metric])" }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($totalUsers -gt 0) {
    $userRows = @($summaryOutput | Select-Object -Property DisplayName, UPN, DeviceCount)
    Write-Output "$totalUsers user(s) with more than five devices"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Users" })
    Write-Output $userRows

    $deviceColumns = if ($IntuneOnlyDevices) { @("UserUPN", "DeviceName", "Compliant") } else { @("UserUPN", "DeviceName", "InIntune", "Compliant") }
    $deviceRows = @($detailedOutput | Select-Object -Property $deviceColumns)
    Write-Output "$totalDevices device(s) of these users"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Devices" })
    Write-Output $deviceRows
}
else {
    Write-Output "No users with more than five devices."
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
