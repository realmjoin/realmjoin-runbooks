<#
.SYNOPSIS
    Generate and email a license availability report based on configured thresholds

.DESCRIPTION
    This runbook checks the license availability based on the transmitted SKUs and sends an email report if any thresholds are reached.
    Two types of thresholds can be configured. The first type is a minimum threshold, which triggers an alert when the number of available licenses falls below a specified number.
    The second type is a maximum threshold, which triggers an alert when the number of available licenses exceeds a specified number.
    The report includes detailed information about licenses that are outside the configured thresholds, exports them to CSV files, and sends them via email.

.PARAMETER InputJson
    JSON array containing SKU configurations with thresholds. Each entry should include:
    - SKUPartNumber: The Microsoft SKU identifier
    - FriendlyName: Display name for the license
    - MinThreshold: (Optional) Minimum number of licenses that should be available
    - MaxThreshold: (Optional) Maximum number of licenses that should be available

    This needs to be configured in the runbook customization

.PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

.PARAMETER CallerName
    Internal parameter for tracking purposes

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
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
            "EmailFrom": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

param (
    [Parameter(Mandatory = $true)]
    $InputJson,

    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "InputJson: $($InputJson.Length) characters" -Verbose

#endregion RJ Log Part


########################################################
#region     Parameter Validation
#
########################################################

# Validate Email Addresses
if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    exit
}

if (-not $EmailTo) {
    Write-RjRbLog -Message "The recipient email address is required. It could be a single address or multiple comma-separated addresses." -Verbose
    throw "The recipient email address is required."
}

#endregion Parameter Validation


########################################################
#region     Function Definitions
#
########################################################

function Get-AllGraphPage {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPage takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
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
        elseif ($response.'@odata.context') {
            # Single item response
            $allResults += $response
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = $response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
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
$allLicenses = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
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
Write-Output "Exporting results to CSV..."

$csvFiles = @()

# Export threshold violations
if ($thresholdViolations.Count -gt 0) {
    $violationsCsv = Join-Path $tempDir "License_Threshold_Violations.csv"
    $thresholdViolations | Select-Object SKUPartNumber, FriendlyName, TotalLicenses, UsedLicenses, AvailableLicenses, ViolationType, ThresholdValue, MinThreshold, MaxThreshold |
        Export-Csv -Path $violationsCsv -NoTypeInformation -Encoding UTF8
    $csvFiles += $violationsCsv
    Write-RjRbLog -Message "Exported threshold violations to: $violationsCsv" -Verbose
}

# Display violations in console
if ($thresholdViolations.Count -gt 0) {
    Write-Output ""
    Write-Output "License Threshold Violations:"
    $thresholdViolations | Format-Table -AutoSize
}

#endregion Output/Export

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

$(if ($csvFiles.Count -gt 0) {
@"
- **License_Threshold_Violations.csv**: Detailed information about all threshold violations
"@
} else {
"No CSV files generated (no violations found)."
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
"@

#endregion Prepare Email Content

########################################################
#region     Send Email Report
#
########################################################

# Only send email if there are violations or SKUs not found
if ($totalViolations -gt 0 -or $notFoundCount -gt 0) {
    Write-Output "Sending email report..."
    Write-Output ""

    $emailSubject = "License Threshold Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom `
                           -EmailTo $EmailTo `
                           -Subject $emailSubject `
                           -MarkdownContent $markdownContent `
                           -Attachments $csvFiles `
                           -TenantDisplayName $tenantDisplayName `
                           -ReportVersion $Version

        Write-Output "Email report sent successfully"
    }
    catch {
        Write-Error "Failed to send email report: $_"
        throw
    }
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

Write-RjRbLog -Message "License threshold email report completed successfully" -Verbose

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
