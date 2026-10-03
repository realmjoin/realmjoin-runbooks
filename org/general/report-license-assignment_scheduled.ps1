<#
	.SYNOPSIS
	Alert when license availability crosses thresholds

	.DESCRIPTION
	Checks how many licenses of the configured SKUs are still available. When a count drops below a minimum or rises above a maximum threshold, the affected SKUs are reported so you can buy or reclaim licenses in time. The report can be sent by email or provided as a download link.

	.PARAMETER InputJson
	SKU list with friendly names and minimum and maximum thresholds, as a JSON array. Preset in the runbook customization.

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
			"InputJson": {
				"Hide": true,
				"DefaultValue": [
					{
						"SKUPartNumber": "SPE_E5",
						"FriendlyName": "Microsoft 365 E5",
						"MinThreshold": 20,
						"MaxThreshold": 30
					},
					{
						"SKUPartNumber": "FLOW_FREE",
						"FriendlyName": "Microsoft Power Automate Free",
						"MinThreshold": 10
					}
				]
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
			"SendEmailReport": {
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
				"DisplayAfter": "InputJson",
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
    [Parameter(Mandatory = $true)]
    $InputJson,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-license-assignment",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

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

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "InputJson: $($InputJson.Length) characters" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose

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

# Convert the license configuration (JSON string or already deserialized array) to PowerShell objects
try {
    if ($InputJson -is [string]) {
        Write-RjRbLog -Message "InputJson is a string, converting from JSON..." -Verbose
        $inputData = $InputJson | ConvertFrom-Json -Depth 10
    }
    elseif ($InputJson -is [array] -or $InputJson -is [System.Collections.ArrayList]) {
        Write-RjRbLog -Message "InputJson is already an array/object" -Verbose
        $inputData = $InputJson
    }
    else {
        Write-RjRbLog -Message "InputJson type: $($InputJson.GetType().Name)" -Verbose
        # Try to convert anyway
        $inputData = $InputJson | ConvertFrom-Json -Depth 10
    }
    $inputData = @($inputData)
}
catch {
    Write-Error -Message "Failed to parse the license configuration (InputJson): $($_.Exception.Message)" -ErrorAction Continue
    Write-RjRbLog -Message "InputJson content: $InputJson" -Verbose
    throw "Invalid JSON format in InputJson parameter. Please ensure the parameter contains a valid JSON array."
}

Write-Output "Loaded $($inputData.Count) license configuration(s)."
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

function Test-LicenseThreshold {
    <#
        .SYNOPSIS
        Checks if a license violates configured minimum or maximum thresholds.

        .DESCRIPTION
        Tests license availability against configured MinThreshold and MaxThreshold values.
        Returns detailed information if a threshold is violated, null otherwise.

        .PARAMETER SKUPartNumber
        The Microsoft SKU identifier to check

        .PARAMETER FriendlyName
        Display name for the license

        .PARAMETER MinThreshold
        Minimum number of licenses that should be available (optional)

        .PARAMETER MaxThreshold
        Maximum number of licenses that should be available (optional)

        .PARAMETER AllLicenses
        Array of all tenant licenses retrieved from Microsoft Graph

        .OUTPUTS
        PSCustomObject with license details if threshold is violated, null otherwise
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$SKUPartNumber,

        [Parameter(Mandatory = $true)]
        [string]$FriendlyName,

        [int]$MinThreshold,

        [int]$MaxThreshold,

        [Parameter(Mandatory = $true)]
        [array]$AllLicenses
    )

    $licenseDetails = $AllLicenses | Where-Object { $_.skuPartNumber -eq $SKUPartNumber }

    if ($null -eq $licenseDetails) {
        return "SKU_NOT_FOUND"
    }

    $usedLicenses = $licenseDetails.consumedUnits
    $totalLicenses = $licenseDetails.prepaidUnits.enabled
    $availableLicenses = $totalLicenses - $usedLicenses

    $violationType = $null
    $thresholdValue = $null

    # Check minimum threshold
    if ($MinThreshold -gt 0 -and $availableLicenses -lt $MinThreshold) {
        $violationType = "Below Minimum"
        $thresholdValue = $MinThreshold
    }
    # Check maximum threshold
    elseif ($MaxThreshold -gt 0 -and $availableLicenses -gt $MaxThreshold) {
        $violationType = "Above Maximum"
        $thresholdValue = $MaxThreshold
    }

    if ($null -ne $violationType) {
        return [PSCustomObject]@{
            SKUPartNumber      = $SKUPartNumber
            FriendlyName       = $FriendlyName
            TotalLicenses      = $totalLicenses
            UsedLicenses       = $usedLicenses
            AvailableLicenses  = $availableLicenses
            ViolationType      = $violationType
            ThresholdValue     = $thresholdValue
            MinThreshold       = if ($MinThreshold -gt 0) { $MinThreshold } else { "Not Set" }
            MaxThreshold       = if ($MaxThreshold -gt 0) { $MaxThreshold } else { "Not Set" }
        }
    }

    return $null
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

# Tenant display name and default domain for the email subject and body (needs Organization.Read.All)
$tenantDisplayName = "Unknown Tenant"
$tenantDomain = ""
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName,verifiedDomains" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenant = $organizationResponse.value[0]
        $tenantDisplayName = $tenant.displayName
        $tenantDomain = ($tenant.verifiedDomains | Where-Object { $_.isDefault -eq $true }).name
        Write-RjRbLog -Message "Tenant: $tenantDisplayName ($($tenant.id))" -Verbose
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
Write-Output "Get Licenses"
Write-Output "---------------------"

try {
    $allLicenses = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/subscribedSkus")
}
catch {
    Write-Error "Failed to retrieve the licenses of the tenant from Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve the subscribed SKUs"
}
Write-Output "Found $($allLicenses.Count) license SKU(s) in the tenant."

Write-Output ""
Write-Output "Check License Thresholds"
Write-Output "---------------------"

# Track violations, SKUs within their thresholds and configured SKUs that do not exist in the tenant
$thresholdViolations = @()
$withinThresholds = @()
$notFoundSKUs = @()
$processedCount = 0

foreach ($item in $inputData) {
    $processedCount++
    Write-Output "  [$processedCount/$($inputData.Count)] Checking $($item.SKUPartNumber) - $($item.FriendlyName)"

    # Extract thresholds from input (support both old and new parameter names)
    $minThreshold = 0
    $maxThreshold = 0

    if ($item.PSObject.Properties.Name -contains "MinThreshold") {
        $minThreshold = $item.MinThreshold
    }
    elseif ($item.PSObject.Properties.Name -contains "WarningThreshold") {
        # Legacy support for old parameter name
        $minThreshold = $item.WarningThreshold
    }

    if ($item.PSObject.Properties.Name -contains "MaxThreshold") {
        $maxThreshold = $item.MaxThreshold
    }

    $result = Test-LicenseThreshold -SKUPartNumber $item.SKUPartNumber `
                                      -FriendlyName $item.FriendlyName `
                                      -MinThreshold $minThreshold `
                                      -MaxThreshold $maxThreshold `
                                      -AllLicenses $allLicenses

    if ($result -eq "SKU_NOT_FOUND") {
        Write-Output "    SKU not found in the tenant"
        $notFoundSKUs += [PSCustomObject]@{
            FriendlyName  = $item.FriendlyName
            SKUPartNumber = $item.SKUPartNumber
        }
    }
    elseif ($null -ne $result) {
        Write-Output "    Threshold violation: $($result.ViolationType) (Available: $($result.AvailableLicenses), Threshold: $($result.ThresholdValue))"
        $thresholdViolations += $result
    }
    else {
        $licenseDetails = $allLicenses | Where-Object { $_.skuPartNumber -eq $item.SKUPartNumber }
        $availableLicenses = $licenseDetails.prepaidUnits.enabled - $licenseDetails.consumedUnits
        Write-Output "    Within thresholds (Available: $availableLicenses)"
        $withinThresholds += [PSCustomObject]@{
            FriendlyName      = $item.FriendlyName
            SKUPartNumber     = $item.SKUPartNumber
            AvailableLicenses = $availableLicenses
            MinThreshold      = if ($minThreshold -gt 0) { $minThreshold } else { "Not Set" }
            MaxThreshold      = if ($maxThreshold -gt 0) { $maxThreshold } else { "Not Set" }
            TotalLicenses     = $licenseDetails.prepaidUnits.enabled
            UsedLicenses      = $licenseDetails.consumedUnits
        }
    }
}

Write-RjRbLog -Message "Processed all $processedCount license configuration(s)" -Verbose

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$totalViolations = $thresholdViolations.Count
$belowMinCount = @($thresholdViolations | Where-Object { $_.ViolationType -eq "Below Minimum" }).Count
$aboveMaxCount = @($thresholdViolations | Where-Object { $_.ViolationType -eq "Above Maximum" }).Count
$notFoundCount = $notFoundSKUs.Count
$withinCount = $withinThresholds.Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "License configurations checked: $($inputData.Count)"
Write-Output "Within thresholds: $withinCount"
Write-Output "Below minimum threshold: $belowMinCount"
Write-Output "Above maximum threshold: $aboveMaxCount"
Write-Output "SKUs not found in the tenant: $notFoundCount"

if ($totalViolations -eq 0 -and $notFoundCount -eq 0) {
    Write-Output "All licenses are within the configured thresholds."
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null

# Report files list the threshold violations; they are only needed when they will be emailed and/or uploaded
if (($sendEmail -or $CreateDownloadLink) -and $thresholdViolations.Count -gt 0) {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "LicenseReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    $violationData = $thresholdViolations | Select-Object SKUPartNumber, FriendlyName, TotalLicenses, UsedLicenses, AvailableLicenses, ViolationType, ThresholdValue, MinThreshold, MaxThreshold

    if ($ReportFileFormat -ne 'XLSX only') {
        $violationsCsv = Join-Path $tempDir "License_Threshold_Violations.csv"
        $violationData | Export-Csv -Path $violationsCsv -NoTypeInformation -Encoding UTF8
        $reportFiles += $violationsCsv
        Write-RjRbLog -Message "Exported threshold violations to: $violationsCsv" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir "License_Threshold_Violations.xlsx"
        $violationData | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Threshold violations"
        $reportFiles += $xlsxPath
        Write-RjRbLog -Message "Exported threshold violations to: $xlsxPath" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($sendEmail -or $CreateDownloadLink) {
    Write-RjRbLog -Message "No threshold violations - no report files created" -Verbose
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
        Write-Output "No threshold violations were found - skipping the upload."
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

# Only send an email when it is selected and there are violations or SKUs that were not found
if (-not $sendEmail) {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}
elseif ($totalViolations -eq 0 -and $notFoundCount -eq 0) {
    Write-Output ""
    Write-Output "No violations or configuration issues detected - email not sent."
    Write-RjRbLog -Message "All licenses are within configured thresholds and no SKUs are missing" -Verbose
}
else {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    $emailSubject = "License Threshold Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    # Build warning section for SKUs not found
    $skuWarningSection = ""
    if ($notFoundCount -gt 0) {
        $skuList = ($notFoundSKUs | ForEach-Object { "- $($_.FriendlyName) ($($_.SKUPartNumber))" }) -join "`n"
        $skuWarningSection = @"

## Configuration Issues

**Warning:** $notFoundCount SKU(s) could not be found in the tenant:

$skuList

**Possible reasons:**
- The license is not available in the tenant
- The SKU part number in the configuration is incorrect
- The license has been removed or renamed

**Recommendation:** Please review the license configuration in the runbook customization.

"@
    }

    # Create markdown content for email
    $markdownContent = @"
# License Threshold Report

This report provides information about licenses that are outside configured thresholds in your Entra ID tenant.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Violations** | $totalViolations |
| **Below Minimum Threshold** | $belowMinCount |
| **Above Maximum Threshold** | $aboveMaxCount |
| **SKUs Not Found** | $notFoundCount |
| **Tenant Domain** | $tenantDomain |

$($skuWarningSection)

## Threshold Violations

$(if ($thresholdViolations.Count -gt 0) {
@"
### Licenses Outside Thresholds

The following licenses have violated their configured thresholds:

| SKU | Friendly Name | Total | Used | Available | Violation Type | Threshold |
|-----|---------------|-------|------|-----------|----------------|-----------|
$(($thresholdViolations | ForEach-Object {
"| $($_.SKUPartNumber) | $($_.FriendlyName) | $($_.TotalLicenses) | $($_.UsedLicenses) | $($_.AvailableLicenses) | $($_.ViolationType) | $($_.ThresholdValue) |"
}) -join "`n")

### Violation Details

$(($thresholdViolations | ForEach-Object {
    $recommendation = if ($_.ViolationType -eq "Below Minimum") {
        "**Action Required:** Consider purchasing additional licenses to avoid service interruptions."
    } else {
        "**Information:** You have more licenses available than the maximum threshold. This may indicate over-provisioning."
    }
@"
#### $($_.FriendlyName) ($($_.SKUPartNumber))
- **Violation Type:** $($_.ViolationType)
- **Available Licenses:** $($_.AvailableLicenses)
- **Threshold Value:** $($_.ThresholdValue)
- **Total Licenses:** $($_.TotalLicenses)
- **Used Licenses:** $($_.UsedLicenses)

$recommendation

"@
}) -join "")
"@
} else {
"No threshold violations detected."
})

## Threshold Configuration

### How Thresholds Work

- **Minimum Threshold:** Alert when available licenses fall **below** this number
- **Maximum Threshold:** Alert when available licenses **exceed** this number

You can configure one or both thresholds for each license type in the runbook customization.

## Data Files

$(if ($reportFiles.Count -gt 0) {
@"
The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **License_Threshold_Violations.csv**: Detailed information about all threshold violations (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **License_Threshold_Violations.xlsx**: The same list as a formatted Excel workbook" })
"@
} else {
"No report files generated (no violations found)."
})

$(if ($belowMinCount -gt 0 -or $aboveMaxCount -gt 0 -or $notFoundCount -gt 0) {
@"

## Recommendations

"@

if ($belowMinCount -gt 0) {
@"

### For Licenses Below Minimum Threshold

1. Review current license assignments and usage
2. Purchase additional licenses before running out
3. Consider implementing license reclamation processes
4. Monitor trends to predict future needs

"@
}

if ($aboveMaxCount -gt 0) {
@"

### For Licenses Above Maximum Threshold

1. Review if excess licenses are needed
2. Consider reducing license purchases in next renewal
3. Evaluate license optimization opportunities
4. Check for unused or unnecessary assignments

"@
}

if ($notFoundCount -gt 0) {
@"

### For Missing SKUs

1. Verify SKU part numbers in configuration
2. Check if licenses have been removed from tenant
3. Update configuration to use correct SKU identifiers

"@
}
})

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# License Threshold Report

This report provides information about licenses that are outside configured thresholds in your Entra ID tenant.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Violations** | $totalViolations |
| **Below Minimum Threshold** | $belowMinCount |
| **Above Maximum Threshold** | $aboveMaxCount |
| **SKUs Not Found** | $notFoundCount |
| **Tenant Domain** | $tenantDomain |

$($skuWarningSection)

## Data Files

- **License_Threshold_Violations.xlsx**: Formatted Excel workbook with all threshold violations

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Choose a report delivery with a download link to obtain the raw CSV file.

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
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath -and (Test-Path -Path $xlsxPath)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the pair is too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
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
    "License configurations checked" = $inputData.Count
    "Within thresholds"              = $withinCount
    "Below minimum threshold"        = $belowMinCount
    "Above maximum threshold"        = $aboveMaxCount
    "SKUs not found in the tenant"   = $notFoundCount
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($thresholdViolations.Count -gt 0) {
    Write-Output "$($thresholdViolations.Count) license(s) outside their thresholds"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Threshold violations" })
    Write-Output @($thresholdViolations | Select-Object -Property FriendlyName, SKUPartNumber, ViolationType, AvailableLicenses, ThresholdValue, MinThreshold, MaxThreshold, TotalLicenses, UsedLicenses)
}
else {
    Write-Output "No license is outside its thresholds."
}

if ($notFoundSKUs.Count -gt 0) {
    Write-Output "$($notFoundSKUs.Count) configured SKU(s) not found in the tenant"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "SKUs not found" })
    Write-Output @($notFoundSKUs | Select-Object -Property FriendlyName, SKUPartNumber)
}
else {
    Write-Output "Every configured SKU exists in the tenant."
}

if ($withinThresholds.Count -gt 0) {
    Write-Output "$($withinThresholds.Count) license(s) within their thresholds"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Within thresholds" })
    Write-Output @($withinThresholds | Select-Object -Property FriendlyName, SKUPartNumber, AvailableLicenses, MinThreshold, MaxThreshold, TotalLicenses, UsedLicenses)
}
else {
    Write-Output "No license is within its thresholds."
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
