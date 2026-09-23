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
			"EmailTo": {
				"DisplayName": "Recipient email address(es)"
			},
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

param (
    [Parameter(Mandatory = $true)]
    $InputJson,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-license-assignment",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
#
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
}
Write-RjRbLog -Message "InputJson: $($InputJson.Length) characters" -Verbose
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
#
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

#endregion Parameter Validation


########################################################
#region     Function Definitions
#
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
#region     Connect and Initialize
#
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

Write-Output "Getting basic tenant information..."
# Get tenant information
$tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
if ($tenant.value -and $tenant.value.Count -gt 0) {
    $tenant = $tenant.value[0]
}
elseif ($tenant.'@odata.context') {
    # Single object response (already extracted)
}
else {
    throw "Unable to retrieve tenant information"
}

$tenantDisplayName = $tenant.displayName
$tenantId = $tenant.id
$tenantDomain = ($tenant.verifiedDomains | Where-Object { $_.isDefault -eq $true }).name

Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

Write-Output "Retrieving all licenses..."
$allLicenses = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
Write-Output "Found $($allLicenses.Count) total licenses in the tenant"

Write-Output "Parsing license configuration..."
# Convert JSON based input to PowerShell object
try {
    # Handle different input types
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

    Write-Output "Loaded $($inputData.Count) license configuration(s) from InputJson"
}
catch {
    Write-Error -Message "Failed to parse InputJson: $_" -ErrorAction Continue
    Write-RjRbLog -Message "InputJson content: $InputJson" -Verbose
    throw "Invalid JSON format in InputJson parameter. Please ensure the parameter contains valid JSON array."
}

Write-Output "Preparing temporary directory for CSV files..."
# Create temporary directory for CSV files
$tempDir = Join-Path (Get-Location).Path "LicenseReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

#endregion Connect and Initialize


########################################################
#region     Data Collection
#
########################################################

Write-Output ""
Write-Output "Checking license thresholds..."

# Track violations and errors
$thresholdViolations = @()
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
        Write-Output "    ❌ SKU not found in tenant"
        $notFoundSKUs += $item.SKUPartNumber
    }
    elseif ($null -ne $result) {
        Write-Output "    ⚠️  Threshold violation: $($result.ViolationType) (Available: $($result.AvailableLicenses), Threshold: $($result.ThresholdValue))"
        $thresholdViolations += $result
    }
    else {
        $licenseDetails = $allLicenses | Where-Object { $_.skuPartNumber -eq $item.SKUPartNumber }
        $availableLicenses = $licenseDetails.prepaidUnits.enabled - $licenseDetails.consumedUnits
        Write-Output "    ✅ Within thresholds (Available: $availableLicenses)"
    }
}

Write-RjRbLog -Message "Processed all $processedCount license configuration(s)" -Verbose

#endregion Data Collection

########################################################
#region     Data Processing
#
########################################################

Write-Output ""
Write-Output "Processing results..."

# Check if there are any violations or errors
if ($thresholdViolations.Count -eq 0 -and $notFoundSKUs.Count -eq 0) {
    Write-Output "✅ All licenses are within configured thresholds. No report will be sent."

    # Clean up temporary directory
    try {
        Remove-Item -Path $tempDir -Recurse -Force
        Write-RjRbLog -Message "Temporary files cleaned up successfully" -Verbose
    }
    catch {
        Write-Warning "Failed to clean up temporary directory: $_"
    }

    Write-Output ""
    Write-Output "Done!"
    exit
}

Write-Output "⚠️  Found $($thresholdViolations.Count) threshold violation(s) and $($notFoundSKUs.Count) SKU(s) not found"

#endregion Data Processing


########################################################
#region     Output/Export
#
########################################################

Write-Output ""
Write-Output "Exporting results..."

$reportFiles = @()
$xlsxPath = $null

# Export threshold violations (report files are only needed when they will be emailed and/or uploaded)
if (($EmailTo -or $CreateDownloadLink) -and $thresholdViolations.Count -gt 0) {
    $violationData = $thresholdViolations | Select-Object SKUPartNumber, FriendlyName, TotalLicenses, UsedLicenses, AvailableLicenses, ViolationType, ThresholdValue, MinThreshold, MaxThreshold

    if ($ReportFileFormat -ne 'XLSX only') {
        $violationsCsv = Join-Path $tempDir "License_Threshold_Violations.csv"
        $violationData | Export-Csv -Path $violationsCsv -NoTypeInformation -Encoding UTF8
        $reportFiles += $violationsCsv
        Write-RjRbLog -Message "Exported threshold violations to: $violationsCsv" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir "License_Threshold_Violations.xlsx"
        $violationData | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "License Assignment"
        $reportFiles += $xlsxPath
        Write-RjRbLog -Message "Exported threshold violations to: $xlsxPath" -Verbose
    }
}

# Display violations in console
if ($thresholdViolations.Count -gt 0) {
    Write-Output ""
    Write-Output "License Threshold Violations:"
    $thresholdViolations | Format-Table -AutoSize
}

#endregion Output/Export

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
#
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
        Write-Output "No threshold violations were found - skipping report upload."
    }
}

#endregion Upload / Download Link

########################################################
#region     Prepare Email Content
#
########################################################

Write-Output ""
Write-Output "Preparing email content..."

# Generate statistics
$totalViolations = $thresholdViolations.Count
$belowMinCount = ($thresholdViolations | Where-Object { $_.ViolationType -eq "Below Minimum" }).Count
$aboveMaxCount = ($thresholdViolations | Where-Object { $_.ViolationType -eq "Above Maximum" }).Count
$notFoundCount = $notFoundSKUs.Count

# Build warning section for SKUs not found
$skuWarningSection = ""
if ($notFoundCount -gt 0) {
    $skuList = ($notFoundSKUs | ForEach-Object { "- $_" }) -join "`n"
    $skuWarningSection = @"

## ⚠️ Configuration Issues

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
    $statusEmoji = if ($_.ViolationType -eq "Below Minimum") { "⚠️" } else { "📈" }
    $recommendation = if ($_.ViolationType -eq "Below Minimum") {
        "**Action Required:** Consider purchasing additional licenses to avoid service interruptions."
    } else {
        "**Information:** You have more licenses available than the maximum threshold. This may indicate over-provisioning."
    }
@"
#### $statusEmoji $($_.FriendlyName) ($($_.SKUPartNumber))
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

#endregion Prepare Email Content

########################################################
#region     Send Email Report
#
########################################################

# Only send email if requested and there are violations or SKUs not found
$brandingMailParams = @{}
if ($EmailTo -and ($totalViolations -gt 0 -or $notFoundCount -gt 0)) {
    Write-Output "Sending email report..."
    Write-Output ""

    $emailSubject = "License Threshold Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    try {
        if ($reportFiles.Count -gt 0) {
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

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $tenantDisplayName
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
            Send-RjReportEmail -EmailFrom $EmailFrom `
                               -EmailTo $EmailTo `
                               -Subject $emailSubject `
                               -MarkdownContent $markdownContent `
                               -TenantDisplayName $tenantDisplayName `
                               -ReportVersion $Version `
                               @brandingMailParams

            Write-Output "Email report sent successfully"
        }
    }
    catch {
        Write-Error "Failed to send email report: $_"
        throw
    }
}
elseif (-not $EmailTo) {
    Write-Output "No recipient email address provided - email not sent"
}
else {
    Write-Output "No violations or configuration issues detected - email not sent"
    Write-RjRbLog -Message "All licenses are within configured thresholds and no SKUs are missing" -Verbose
}

#endregion Send Email Report

########################################################
#region     Cleanup
#
########################################################

# Clean up temporary files
try {
    Remove-Item -Path $tempDir -Recurse -Force
    Write-RjRbLog -Message "Temporary files cleaned up successfully" -Verbose
}
catch {
    Write-Warning "Failed to clean up temporary directory: $_"
}

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-RjRbLog -Message "License threshold email report completed successfully" -Verbose

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
