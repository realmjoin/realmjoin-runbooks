<#
    .SYNOPSIS
    Monitor/Report expiry of Apple device management certificates

    .DESCRIPTION
    Monitors expiration dates of Apple Push certificates, VPP tokens, and DEP tokens in Microsoft Intune.
    Sends an email report with alerts for certificates/tokens expiring within the specified threshold.

    .PARAMETER Days
    The warning threshold in days. Certificates and tokens expiring within this many days will be
    flagged as alerts in the report. Default is 30 days.

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

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
            "BrandingHeaderImageUrl": {
                "Hide": true
            },
            "BrandingFooterImageUrl": {
                "Hide": true
            },
            "BrandingFooterLink": {
                "Hide": true
            },
            "Days": {
                "DisplayName": "Days Until Expiration Warning"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [int] $Days = 30,
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
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

function Get-RjRbBrandingMailParams {
    <#
        .SYNOPSIS
        Resolves the tenant email branding settings into Send-RjReportEmail parameters.

        .DESCRIPTION
        Downloads the custom header/footer image configured via the RJReport.Branding.*
        tenant settings to a temp file, validates it (HTTPS only, PNG/JPEG/GIF by file
        signature, size cap) and returns a hashtable ready to splat into
        Send-RjReportEmail / Send-RjRbGuardedReportEmail.

        A missing setting, a broken URL or an invalid image NEVER fails the report send:
        the affected key is simply omitted (warning logged) and the module falls back to
        the bundled default graphics. Images are downloaded once per run - reuse the
        returned hashtable for every email sent by this job.

        NOTE: This logic is planned to move into the RealmJoin.RunbookHelper module.
        Until then it is duplicated inline in the runbooks.

        .PARAMETER HeaderImageUrl
        Public HTTPS URL of the custom header image (RJReport.Branding.HeaderImageUrl).

        .PARAMETER FooterImageUrl
        Public HTTPS URL of the custom footer image (RJReport.Branding.FooterImageUrl).

        .PARAMETER FooterLink
        URL the footer image links to (RJReport.Branding.FooterLink).

        .PARAMETER TimeoutSec
        Download timeout per image in seconds.

        .PARAMETER MaxImageBytes
        Maximum accepted image file size. Branding images count against the ~4 MB Graph
        sendMail request limit together with the report attachments, so they must stay small.
    #>
    param(
        [string]$HeaderImageUrl,
        [string]$FooterImageUrl,
        [string]$FooterLink,
        [int]$TimeoutSec = 30,
        [long]$MaxImageBytes = 200KB
    )

    $brandingParams = @{}
    if (-not [string]::IsNullOrWhiteSpace($FooterLink)) {
        $brandingParams.FooterLink = $FooterLink.Trim()
    }

    $images = @(
        @{ Kind = 'header'; Url = $HeaderImageUrl; ParamName = 'HeaderImage' },
        @{ Kind = 'footer'; Url = $FooterImageUrl; ParamName = 'FooterImage' }
    )

    foreach ($image in $images) {
        if ([string]::IsNullOrWhiteSpace($image.Url)) { continue }
        $url = $image.Url.Trim()
        $tempFile = $null
        try {
            $uri = [System.Uri]$url
            if ($uri.Scheme -ne 'https') {
                throw "Only HTTPS URLs are supported (got '$url')."
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) `
                ("RjRbBranding-$($image.Kind)-" + [System.Guid]::NewGuid().ToString('N') + '.tmp')

            # Ensure TLS 1.2 on Windows PowerShell 5.1 (no-op on PowerShell 7)
            [System.Net.ServicePointManager]::SecurityProtocol = `
                [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

            $previousProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop | Out-Null
            }
            finally {
                $ProgressPreference = $previousProgressPreference
            }

            $fileItem = Get-Item -LiteralPath $tempFile -ErrorAction Stop
            if ($fileItem.Length -eq 0) { throw "The downloaded file is empty." }
            if ($fileItem.Length -gt $MaxImageBytes) {
                throw "The image is $([math]::Round($fileItem.Length / 1KB, 1)) KB and exceeds the $([math]::Round($MaxImageBytes / 1KB, 0)) KB limit for inline email images."
            }

            # Determine the actual image format from the file signature - the URL may have a
            # wrong extension or none at all, and Send-RjReportEmail validates by extension.
            $magic = New-Object byte[] 8
            $stream = [System.IO.File]::OpenRead($tempFile)
            try { [void]$stream.Read($magic, 0, 8) } finally { $stream.Dispose() }

            $extension = $null
            if ($magic[0] -eq 0x89 -and $magic[1] -eq 0x50 -and $magic[2] -eq 0x4E -and $magic[3] -eq 0x47 -and
                $magic[4] -eq 0x0D -and $magic[5] -eq 0x0A -and $magic[6] -eq 0x1A -and $magic[7] -eq 0x0A) {
                $extension = '.png'
            }
            elseif ($magic[0] -eq 0xFF -and $magic[1] -eq 0xD8 -and $magic[2] -eq 0xFF) {
                $extension = '.jpg'
            }
            elseif ($magic[0] -eq 0x47 -and $magic[1] -eq 0x49 -and $magic[2] -eq 0x46 -and $magic[3] -eq 0x38 -and
                ($magic[4] -eq 0x37 -or $magic[4] -eq 0x39) -and $magic[5] -eq 0x61) {
                $extension = '.gif'
            }
            if (-not $extension) {
                throw "The downloaded file is not a PNG, JPEG or GIF image (unrecognized file signature)."
            }

            $finalFile = [System.IO.Path]::ChangeExtension($tempFile, $extension)
            Move-Item -LiteralPath $tempFile -Destination $finalFile -Force -ErrorAction Stop
            $tempFile = $null

            $brandingParams[$image.ParamName] = $finalFile
            Write-RjRbLog -Message "Branding: using the custom $($image.Kind) image from '$url' ($([math]::Round($fileItem.Length / 1KB, 1)) KB, $extension)" -Verbose
        }
        catch {
            Write-RjRbLog -Message "WARNING: Branding: the custom $($image.Kind) image from '$url' could not be used - the default image is used instead. $($_.Exception.Message)" -Verbose
            # Write-Warning (not Write-Output): inside this value-returning function, Write-Output
            # would pollute the returned hashtable and break splatting at the call sites.
            Write-Warning -Message "The custom $($image.Kind) image could not be downloaded or is not a usable image - the report email uses the default $($image.Kind) image instead."
            if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    return $brandingParams
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

#region Apple MDM Cert
Write-Output "Evaluating Apple device management integrations..."

try {
    $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate"
    $applePushResponse = Invoke-MgGraphRequest -Uri $Uri -Method GET -ErrorAction Stop


    if ($applePushResponse) {
        $expiration = if ($applePushResponse.expirationDateTime) { [datetime]$applePushResponse.expirationDateTime } else { $null }
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
            Identifier        = $applePushResponse.appleIdentifier
            ExpirationDate    = $expiration
            DaysRemaining     = $daysRemaining
            DaysRemainingText = Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate
            Status            = $status
            Notes             = $notes
            Alert             = $isAlert
        }

        if ($isAlert) {
            $alertDetails += "- **Apple Push Certificate** '$($applePushResponse.appleIdentifier)': $($notes) ($([string](Get-DaysRemainingText -ExpirationDate $expiration -ReferenceDate $currentDate)))"
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
    $vppTokens = @(Get-GraphPagedResult -Uri $Uri -ErrorAction Stop)

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
catch {
    Write-Warning "Failed to retrieve VPP Tokens: $($_.Exception.Message)"
}
#endregion

#region DEP
try {
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
    $depSettings = @(Get-GraphPagedResult -Uri $Uri -ErrorAction Stop)

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
catch {
    Write-Warning "Failed to retrieve DEP onboarding settings: $($_.Exception.Message)"
}

#endregion
#endregion

$allResults = @($applePushResults + $vppTokenResults + $depTokenResults)
$alertCount = ($allResults | Where-Object { $_.Alert }).Count

Write-Output ""
Write-Output "## Summary"
Write-Output "Apple Push certificate: $(if ($applePushResults.Count -gt 0) { 'Found' } else { 'Not found' })"
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
- **No** Apple Push Notification certificate
- **0** Volume Purchase Program (VPP) tokens
- **0** Device Enrollment Program (DEP) tokens

## Information

This report monitors Apple-specific device management integrations. If your organization does not manage Apple devices through Microsoft Intune, no action is required.

If you expect to see Apple integrations here:
- Verify that Apple Push Notification certificates have been configured in Microsoft Intune
- Check that VPP tokens from Apple Business Manager have been added
- Ensure DEP tokens from Apple Business Manager are properly configured

For more information on setting up Apple device management, please refer to Microsoft Intune documentation.

---

*This email was automatically generated. Please do not reply to this email.*
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

---

*This email was automatically generated. Please do not reply to this email.*
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

$brandingMailParams = @{}
# Only send email if there are alerts to report
if ($alertCount -gt 0) {
    Write-RjRbLog -Message "Preparing to send email report to: $($EmailTo)" -Verbose

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams
        Write-RjRbLog -Message "Email sent successfully to: $($EmailTo)" -Verbose
        Write-Output "Email report sent to '$($EmailTo)'."
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}
else {
    Write-Output "No alerts detected - email not sent."
    Write-RjRbLog -Message "All tracked items are outside the $($Days)-day warning window - email not sent." -Verbose
}
