<#
    .SYNOPSIS
    Monitor/Report expiry of Apple device management certificates

    .DESCRIPTION
    Monitors expiration dates of Apple Push certificates, VPP tokens, and DEP tokens in Microsoft Intune.
    Sends an email report with alerts for certificates/tokens expiring within the specified threshold.

    .PARAMETER Days
    The warning threshold in days. Certificates and tokens expiring within this many days will be
    flagged as alerts in the report. Default is 300 days (approximately 10 months).

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "Days": {
                "DisplayName": "Days Until Expiration Warning"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [int] $Days = 30,
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose

#endregion

########################################################
#region     Parameter Validation
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


########################################################
#region     Function Definitions
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

#endregion

########################################################
#region     Connect and Initialize
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

Write-Output "Getting basic tenant information..."
# Get tenant information
$tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
    $tenant = $tenant.value[0]
}
elseif ($tenant.'@odata.context') {
    # Single tenant response
    $tenant = $tenant
}
else {
    Write-Error "Could not retrieve tenant information" -ErrorAction Continue
    throw "Could not retrieve tenant information"
}

$tenantDisplayName = $tenant.displayName
$tenantId = $tenant.id

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

$thresholdDate = (Get-Date).AddDays($Days)
$currentDate = Get-Date

function Get-DaysRemainingText {
    param(
        [Nullable[datetime]]$ExpirationDate,
        [datetime]$ReferenceDate
    )

    if (-not $ExpirationDate) {
        return "Unknown"
    }

    $remaining = [math]::Floor(($ExpirationDate - $ReferenceDate).TotalDays)

    if ($remaining -lt 0) {
        return "Expired $(-1 * $remaining) day(s) ago"
    }
    elseif ($remaining -eq 0) {
        return "Expires today"
    }

    return "$remaining day(s) remaining"
}

$applePushResults = @()
$vppTokenResults = @()
$depTokenResults = @()
$alertDetails = @()

#region Apple MDM Certs
Write-Output "Evaluating Apple device management integrations..."

try {
    $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate"
    $applePushResponse = Get-AllGraphPage -Uri $Uri -ErrorAction Stop


    if ($applePushResponse) {
        $applePushCerts = @($applePushResponse)

        foreach ($applePushCert in $applePushCerts) {
            $expiration = if ($applePushCert.expirationDateTime) { [datetime]$applePushCert.expirationDateTime } else { $null }
            $daysRemaining = if ($expiration) { [math]::Floor(($expiration - $currentDate).TotalDays) } else { $null }
            $status = "Healthy"
            $notes = ""
            $isAlert = $false

            if ($expiration -and $expiration -le $thresholdDate) {
                $status = "Alert"
                $notes = "Expires within $($Days) days"
                $isAlert = $true
            }

            if (-not $expiration) {
                $status = "Alert"
                $notes = "Expiration date unavailable"
                $isAlert = $true
            }

            $applePushResults += [PSCustomObject]@{
                Category          = "Apple Push Certificate"
                Identifier        = $applePushCert.appleIdentifier
                ExpirationDate    = $expiration
                DaysRemaining     = $daysRemaining
                DaysRemainingText = Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate
                Status            = $status
                Notes             = $notes
                Alert             = $isAlert
            }

            if ($isAlert) {
                $alertDetails += "- **Apple Push Certificate** '$($applePushCert.appleIdentifier)': $($notes) ($([string](Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate)))"
            }
        }
    }
}
catch {
    Write-Warning "Failed to retrieve Apple Push Notification Certificate: $($_.Exception.Message)"
}

#endregion

#region VPP and DEP Tokens
#region VPP

try {
    $Uri = "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens"
    $vppTokens = Get-AllGraphPage -Uri $Uri -ErrorAction Stop
    if ($vppTokens.ContainsKey("value")) {
        $vppTokens = @()
        $vppTokenResults = @()
    }
    else {
        foreach ($token in $vppTokens) {
            $identifier = if ([string]::IsNullOrWhiteSpace($token.appleId)) { "Unknown Apple ID" } else { $token.appleId }
            $expiration = if ($token.expirationDateTime) { [datetime]$token.expirationDateTime } else { $null }
            $daysRemaining = if ($expiration) { [math]::Floor(($expiration - $currentDate).TotalDays) } else { $null }
            $status = "Healthy"
            $notes = ""
            $isAlert = $false

            if ($token.state -ne "valid") {
                $status = "Alert"
                $stateText = if ([string]::IsNullOrWhiteSpace($token.state)) { "unknown" } else { $token.state }
                $notes = "Token state is '$stateText'"
                $isAlert = $true
            }
            elseif ($expiration -and $expiration -le $thresholdDate) {
                $status = "Alert"
                $notes = "Expires within $($Days) days"
                $isAlert = $true
            }

            if (-not $expiration) {
                $status = "Alert"
                $notes = if ($notes) { "$($notes); expiration date unavailable" } else { "Expiration date unavailable" }
                $isAlert = $true
            }

            $vppTokenResults += [PSCustomObject]@{
                Category          = "VPP Token"
                Identifier        = $identifier
                ExpirationDate    = $expiration
                DaysRemaining     = $daysRemaining
                DaysRemainingText = Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate
                Status            = $status
                Notes             = $notes
                Alert             = $isAlert
            }

            if ($isAlert) {
                $alertDetails += "- **VPP Token** '$identifier': $notes ($([string](Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate)))"
            }
        }
    }


}
catch {
    Write-Warning "Failed to retrieve VPP Tokens: $($_.Exception.Message)"
}
#endregion

#region DEP
try {
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
    $depSettings = Get-AllGraphPage -Uri $Uri -ErrorAction Stop

    if ($depSettings.'@odata.count' -eq 0) {
        $depSettings = @()
        $depTokenResults = @()
    }
    else {
        foreach ($token in $depSettings) {
            $identifier = if ([string]::IsNullOrWhiteSpace($token.appleIdentifier)) { "Unknown Identifier" } else { $token.appleIdentifier }
            $expiration = if ($token.tokenExpirationDateTime) { [datetime]$token.tokenExpirationDateTime } else { $null }
            $daysRemaining = if ($expiration) { [math]::Floor(($expiration - $currentDate).TotalDays) } else { $null }
            $status = "Healthy"
            $notes = ""
            $isAlert = $false

            if ($expiration -and $expiration -le $thresholdDate) {
                $status = "Alert"
                $notes = "Expires within $($Days) days"
                $isAlert = $true
            }

            if (-not $expiration) {
                $status = "Alert"
                $notes = "Expiration date unavailable"
                $isAlert = $true
            }

            $depTokenResults += [PSCustomObject]@{
                Category          = "DEP Token"
                Identifier        = $identifier
                ExpirationDate    = $expiration
                DaysRemaining     = $daysRemaining
                DaysRemainingText = Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate
                Status            = $status
                Notes             = $notes
                Alert             = $isAlert
            }

            if ($isAlert) {
                $alertDetails += "- **DEP Token** '$identifier': $notes ($([string](Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate)))"
            }
        }
    }
}
catch {
    Write-Warning "Failed to retrieve DEP onboarding settings: $($_.Exception.Message)"
}

#endregion
#endregion

$allResults = @($applePushResults + $vppTokenResults + $depTokenResults)
$alertCount = ($allResults | Where-Object { $_.Alert }).Count

Write-Output ""
Write-Output "## Summary"
Write-Output "Apple Push certificates: $($applePushResults.Count)"
Write-Output "VPP tokens: $($vppTokenResults.Count)"
Write-Output "DEP tokens: $($depTokenResults.Count)"
Write-Output "Alerts detected: $alertCount"

# Check if no Apple infrastructure exists
$hasNoAppleInfrastructure = ($applePushResults.Count -eq 0 -and $vppTokenResults.Count -eq 0 -and $depTokenResults.Count -eq 0)

$applePushTable = if ($applePushResults.Count -gt 0) {
    $rows = foreach ($entry in $applePushResults) {
        $expiresText = if ($entry.ExpirationDate) { $entry.ExpirationDate.ToString("yyyy-MM-dd") } else { "Unknown" }
        $statusText = if ($entry.Notes) { "$($entry.Status) - $($entry.Notes)" } else { $entry.Status }
        $identifierText = if ([string]::IsNullOrWhiteSpace($entry.Identifier)) { "Unknown" } else { $entry.Identifier }
        "| $identifierText | $expiresText | $($entry.DaysRemainingText) | $statusText |"
    }

    @"
| Identifier | Expires | Days Remaining | Status |
|------------|---------|----------------|--------|
$($rows -join "`n")
"@
}
else {
    "No Apple Push Notification certificates were found."
}

$vppTable = if ($vppTokenResults.Count -gt 0) {
    $rows = foreach ($entry in $vppTokenResults) {
        $expiresText = if ($entry.ExpirationDate) { $entry.ExpirationDate.ToString("yyyy-MM-dd") } else { "Unknown" }
        $statusText = if ($entry.Notes) { "$($entry.Status) - $($entry.Notes)" } else { $entry.Status }
        $identifierText = if ([string]::IsNullOrWhiteSpace($entry.Identifier)) { "Unknown" } else { $entry.Identifier }
        "| $identifierText | $expiresText | $($entry.DaysRemainingText) | $statusText |"
    }

    @"
| Apple ID | Expires | Days Remaining | Status |
|----------|---------|----------------|--------|
$($rows -join "`n")
"@
}
else {
    "No VPP tokens were found."
}

$depTable = if ($depTokenResults.Count -gt 0) {
    $rows = foreach ($entry in $depTokenResults) {
        $expiresText = if ($entry.ExpirationDate) { $entry.ExpirationDate.ToString("yyyy-MM-dd") } else { "Unknown" }
        $statusText = if ($entry.Notes) { "$($entry.Status) - $($entry.Notes)" } else { $entry.Status }
        $identifierText = if ([string]::IsNullOrWhiteSpace($entry.Identifier)) { "Unknown" } else { $entry.Identifier }
        "| $identifierText | $expiresText | $($entry.DaysRemainingText) | $statusText |"
    }

    @"
| Identifier | Expires | Days Remaining | Status |
|------------|---------|----------------|--------|
$($rows -join "`n")
"@
}
else {
    "No DEP onboarding tokens were found."
}

$alertsSection = if ($alertCount -gt 0) {
    "## Alerts`n`n" + ($alertDetails -join "`n")
}
else {
    "## Alerts`n`nNo alerts were detected. All tracked items are outside the $($Days)-day warning window."
}

# Generate different markdown content based on whether Apple infrastructure exists
if ($hasNoAppleInfrastructure) {
    $markdownContent = @"
# Apple Intune Integration Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Warning threshold: $($Days) day(s)

## Summary

No Apple device management infrastructure was detected in this tenant.

## Details

This tenant currently has:
- **0** Apple Push Notification certificates
- **0** Volume Purchase Program (VPP) tokens
- **0** Device Enrollment Program (DEP) tokens

## Information

This report monitors Apple-specific device management integrations. If your organization does not manage Apple devices through Microsoft Intune, no action is required.

If you expect to see Apple integrations here:
- Verify that Apple Push Notification certificates have been configured in Microsoft Intune
- Check that VPP tokens from Apple Business Manager have been added
- Ensure DEP tokens from Apple Business Manager are properly configured

For more information on setting up Apple device management, please refer to Microsoft Intune documentation.
"@
}
else {
    $markdownContent = @"
# Apple Intune Integration Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Warning threshold: $($Days) day(s)
- Alerts detected: $($alertCount)

$alertsSection

## Apple Push Notification Certificate

$applePushTable

## Volume Purchase Program Tokens

$vppTable

## Device Enrollment Program Tokens

$depTable

## Recommendations

- Review certificates and tokens that show an alert status.
- Renew any items scheduled to expire within the warning window.
- For invalid tokens, resolve state issues in Apple Business Manager.
"@
}

$emailSubject = if ($hasNoAppleInfrastructure) {
    "[Automated eMail] Apple Intune integration status - No Apple infrastructure detected."
}
elseif ($alertCount -gt 0) {
    "[Automated eMail] ALERT - Apple Intune integration warnings."
}
else {
    "[Automated eMail] Apple Intune integration status."
}

Write-RjRbLog -Message "Preparing to send email report to: $($EmailTo)" -Verbose

try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version
    Write-RjRbLog -Message "Email sent successfully to: $($EmailTo)" -Verbose
    Write-Output "Email report sent to '$($EmailTo)'."
}
catch {
    Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
    throw
}
