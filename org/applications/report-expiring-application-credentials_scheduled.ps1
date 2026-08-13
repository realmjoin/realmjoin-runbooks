<#
    .SYNOPSIS
    List expiry date of all Application Registration credentials

    .DESCRIPTION
    This runbook lists the expiry dates of application registration credentials, including client secrets and certificates.
    It can optionally filter by application IDs and can limit output to credentials that are about to expire.

    Optionally, the report can be sent via email with CSV and/or Excel (xlsx) attachments.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER listOnlyExpiring
    If only credentials that are about to expire within the specified number of days should be listed, select "List only credentials about to expire" (final value: true).
    If you want to list all credentials regardless of their expiry date, select "List all credentials" (final value: false).

    .PARAMETER Days
    The number of days before a credential expires to consider it "about to expire".

    .PARAMETER CredentialType
    Filter by credential type: "Both" (default), "ClientSecrets", or "Certificates".

    .PARAMETER ApplicationIds
    Optional - comma-separated list of Application IDs to filter the credentials.

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

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "listOnlyExpiring": {
                "Select": {
                    "Options": [
                        {
                            "Display": "List only credentials about to expire",
                            "Value": true
                        },
                        {
                            "Display": "List all credentials",
                            "Value": false,
                            "Customization": {
                                "Hide": [
                                    "Days"
                                ]
                            }
                        }
                    ]
                }
            },
            "Days": {
                "DisplayName": "Days before credential expiry"
            },
            "CredentialType": {
                "DisplayName": "Credential Type Filter",
                "Select": {
                    "Options": [
                        {
                            "Display": "Client Secrets and Certificates",
                            "Value": "Both"
                        },
                        {
                            "Display": "Only Client Secrets",
                            "Value": "ClientSecrets"
                        },
                        {
                            "Display": "Only Certificates",
                            "Value": "Certificates"
                        }
                    ]
                }
            },
            "ApplicationIds": {
                "DisplayName": "Application IDs"
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
            "EmailFrom": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

# Suppress false positive from PSScriptAnalyzer - CredentialType is a type selector (Both/ClientSecrets/Certificates), not a password
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialType")]
param(
    [bool] $listOnlyExpiring = $true,

    [int] $Days = 30,

    [ValidateSet("Both", "ClientSecrets", "Certificates")]
    [string] $CredentialType = "Both",

    [string] $ApplicationIds,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-expiring-app-credentials",

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

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "List Only Expiring: $listOnlyExpiring" -Verbose
Write-RjRbLog -Message "Days before expiry: $Days" -Verbose
Write-RjRbLog -Message "Credential Type: $CredentialType" -Verbose
Write-RjRbLog -Message "Application IDs: $ApplicationIds" -Verbose

# Add Parameter in Verbose output
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
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
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
        exit
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

function Send-RjRbGuardedReportEmail {
    <#
        .SYNOPSIS
        Sends a report email via Send-RjReportEmail with an attachment size guard.

        .DESCRIPTION
        Wraps Send-RjReportEmail: when the attachments are likely to exceed the Graph sendMail
        request limit (~4 MB total; attachments count base64-encoded, +33%), the email is sent
        with a smaller fallback attachment set instead. If the send fails anyway, one retry with
        the fallback set is attempted before failing hard with an actionable error message.

        The function is content-agnostic - which files form the regular and the fallback set
        (e.g. all files vs. only the Excel workbook) is decided by the caller.

        NOTE: This logic is planned to move into Send-RjReportEmail in the
        RealmJoin.RunbookHelper module. Until then it is duplicated inline in the runbooks.

        .PARAMETER EmailFrom
        Sender address, passed through to Send-RjReportEmail.

        .PARAMETER EmailTo
        Recipient address(es), passed through to Send-RjReportEmail.

        .PARAMETER Subject
        Mail subject, passed through to Send-RjReportEmail.

        .PARAMETER MarkdownContent
        Mail body (Markdown) used when the regular attachment set is sent.

        .PARAMETER Attachments
        The regular attachment set (file paths). May be empty for a text-only mail.

        .PARAMETER FallbackAttachments
        Optional smaller attachment set used when the regular set exceeds the size budget or
        its send attempt fails. Without this parameter there is no fallback - a failed send
        throws immediately.

        .PARAMETER FallbackMarkdownContent
        Mail body (Markdown) used when the fallback attachment set is sent.

        .PARAMETER MaxAttachmentBytes
        Raw size budget for the regular attachment set (default 2.5MB - stays safely below
        the ~4 MB Graph sendMail request limit after base64 encoding and HTML body overhead).

        .PARAMETER TenantDisplayName
        Tenant name for the report footer, passed through to Send-RjReportEmail.

        .PARAMETER ReportVersion
        Runbook version for the report footer, passed through to Send-RjReportEmail.

        .PARAMETER HeaderImage
        Optional local path of a custom header image, passed through to Send-RjReportEmail.

        .PARAMETER FooterImage
        Optional local path of a custom footer image, passed through to Send-RjReportEmail.

        .PARAMETER FooterLink
        Optional URL the footer image links to, passed through to Send-RjReportEmail.

        .PARAMETER UseNativeGraphRequest
        Passed through to Send-RjReportEmail.

        .EXAMPLE
        PS C:\> Send-RjRbGuardedReportEmail -EmailFrom $from -EmailTo $to -Subject $subject `
                    -MarkdownContent $md -Attachments ($csvFiles + $xlsxPath) `
                    -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $mdFallback `
                    -TenantDisplayName $tenant -ReportVersion $Version
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailFrom,

        [Parameter(Mandatory = $true)]
        [string]$EmailTo,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$MarkdownContent,

        [AllowEmptyCollection()]
        [string[]]$Attachments = @(),

        [string[]]$FallbackAttachments,

        [string]$FallbackMarkdownContent,

        [long]$MaxAttachmentBytes = 2.5MB,

        [string]$TenantDisplayName,

        [string]$ReportVersion,

        [string]$HeaderImage,

        [string]$FooterImage,

        [string]$FooterLink,

        [switch]$UseNativeGraphRequest
    )

    $baseParams = @{
        EmailFrom = $EmailFrom
        EmailTo   = $EmailTo
        Subject   = $Subject
    }
    if ($TenantDisplayName) { $baseParams.TenantDisplayName = $TenantDisplayName }
    if ($ReportVersion) { $baseParams.ReportVersion = $ReportVersion }
    if ($UseNativeGraphRequest) { $baseParams.UseNativeGraphRequest = $true }
    if ($HeaderImage) { $baseParams.HeaderImage = $HeaderImage }
    if ($FooterImage) { $baseParams.FooterImage = $FooterImage }
    if ($FooterLink) { $baseParams.FooterLink = $FooterLink }

    $sizeLimitHint = "If the attachments exceed the email size limit, choose a different report file format or enable the download link option (CreateDownloadLink) to deliver the files."

    $attachments = @($Attachments | Where-Object { $_ })
    $hasFallback = ($null -ne $FallbackAttachments) -and (@($FallbackAttachments | Where-Object { $_ }).Count -gt 0)

    # Graph sendMail rejects the whole request at ~4 MB; attachments count base64-encoded (+33%),
    # plus HTML body and inline header image. Above this raw budget the fallback set is sent directly.
    $useFallback = $false
    if ($hasFallback -and $attachments.Count -gt 0) {
        $totalBytes = ($attachments | ForEach-Object { (Get-Item -LiteralPath $_).Length } | Measure-Object -Sum).Sum
        if (-not $totalBytes) { $totalBytes = 0 }
        if ($totalBytes -gt $MaxAttachmentBytes) {
            $useFallback = $true
            Write-Output "The attachments total $([math]::Round($totalBytes / 1MB, 2)) MB and exceed the email attachment budget of $([math]::Round($MaxAttachmentBytes / 1MB, 2)) MB - sending the reduced attachment set instead."
        }
    }

    try {
        if ($useFallback) {
            Send-RjReportEmail @baseParams -MarkdownContent $FallbackMarkdownContent -Attachments $FallbackAttachments
            Write-Output "Email report sent successfully to: $EmailTo (reduced attachment set - the full set exceeds the email size limit)"
        }
        elseif ($attachments.Count -gt 0) {
            Send-RjReportEmail @baseParams -MarkdownContent $MarkdownContent -Attachments $attachments
            Write-Output "Email report sent successfully to: $EmailTo"
        }
        else {
            Send-RjReportEmail @baseParams -MarkdownContent $MarkdownContent
            Write-Output "Email report sent successfully to: $EmailTo"
        }
    }
    catch {
        # Safety net: retry once with the fallback set if the full set was just attempted
        if ($useFallback -or -not $hasFallback -or $attachments.Count -eq 0) {
            Write-Error "Failed to send email report: $($_.Exception.Message). $sizeLimitHint"
            throw
        }

        Write-Output "Sending the email with all attachments failed: $($_.Exception.Message)"
        Write-Output "Retrying with the reduced attachment set..."
        try {
            Send-RjReportEmail @baseParams -MarkdownContent $FallbackMarkdownContent -Attachments $FallbackAttachments
            Write-Output "Email report sent successfully to: $EmailTo (reduced attachment set - the first attempt with all attachments failed)"
        }
        catch {
            Write-Error "Failed to send email report (retry with the reduced attachment set also failed): $($_.Exception.Message). $sizeLimitHint"
            throw
        }
    }
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

Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

Write-Output "Preparing temporary file paths for the report files..."
# Create temporary file paths for the report files
$tempDir = (Get-Location).Path
$credsCsv = Join-Path $tempDir "AppCredsExpiry_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$credsXlsx = [System.IO.Path]::ChangeExtension($credsCsv, 'xlsx')


#endregion

########################################################
#region     Retrieve Application Credentials
########################################################

Write-Output "Retrieving application credentials..."

# Split the comma-separated application IDs into an array and trim whitespace
$ApplicationIdArray = @()
if ($ApplicationIds) {
    $ApplicationIdArray = $ApplicationIds -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    Write-RjRbLog -Message "Filtering by $($ApplicationIdArray.Count) Application ID(s)" -Verbose
}

# Determine which credential types to process
$processCertificates = ($CredentialType -eq "Both" -or $CredentialType -eq "Certificates")
$processClientSecrets = ($CredentialType -eq "Both" -or $CredentialType -eq "ClientSecrets")

Write-RjRbLog -Message "Processing Certificates: $processCertificates" -Verbose
Write-RjRbLog -Message "Processing Client Secrets: $processClientSecrets" -Verbose

[array]$apps = @()
$apps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"

Write-Output "Found $((($(($apps) | Measure-Object).Count))) applications/service principals"

$date = Get-Date
$credentialResults = @()

foreach ($app in $apps) {
    if ($ApplicationIdArray -and ($ApplicationIdArray.Count -gt 0) -and ($app.appId -notin $ApplicationIdArray)) {
        continue
    }

    if (($app.keyCredentials) -or ($app.passwordCredentials)) {
        # Process Certificate Credentials (only if filter allows)
        if ($processCertificates) {
            $app.keyCredentials | ForEach-Object {
                $enddate = [datetime]$_.endDateTime
                $startdate = [datetime]$_.startDateTime
                $daysLeft = (New-TimeSpan -Start $date -End $enddate).days

                if ($listOnlyExpiring) {
                    # Only include credentials that are expiring (0 to $Days days left), exclude already expired (negative days)
                    if ($daysLeft -ge 0 -and $daysLeft -le $Days) {
                        $tempObj = [PSCustomObject]@{
                            AppDisplayName = $app.displayName
                            AppId          = $app.appId
                            AppObjectId    = $app.id
                            CredentialType = "Certificate"
                            CredentialName = $_.displayName
                            CredentialId   = $_.keyId
                            StartDateTime  = $startdate
                            EndDateTime    = $enddate
                            DaysLeft       = $daysLeft
                            IsExpired      = ($daysLeft -lt 0)
                            Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le $Days) { "Warning" } else { "Valid" }
                        }
                        $credentialResults += $tempObj
                    }
                }
                else {
                    # Include all credentials (expired, expiring, and valid)
                    $tempObj = [PSCustomObject]@{
                        AppDisplayName = $app.displayName
                        AppId          = $app.appId
                        AppObjectId    = $app.id
                        CredentialType = "Certificate"
                        CredentialName = $_.displayName
                        CredentialId   = $_.keyId
                        StartDateTime  = $startdate
                        EndDateTime    = $enddate
                        DaysLeft       = $daysLeft
                        IsExpired      = ($daysLeft -lt 0)
                        Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le 30) { "Warning" } else { "Valid" }
                    }
                    $credentialResults += $tempObj
                }
            }
        }

        # Process Client Secret Credentials (only if filter allows)
        if ($processClientSecrets) {
            $app.passwordCredentials | ForEach-Object {
                $enddate = [datetime]$_.endDateTime
                $startdate = [datetime]$_.startDateTime
                $daysLeft = (New-TimeSpan -Start $date -End $enddate).days

                if ($listOnlyExpiring) {
                    # Only include credentials that are expiring (0 to $Days days left), exclude already expired (negative days)
                    if ($daysLeft -ge 0 -and $daysLeft -le $Days) {
                        $tempObj = [PSCustomObject]@{
                            AppDisplayName = $app.displayName
                            AppId          = $app.appId
                            AppObjectId    = $app.id
                            CredentialType = "Client Secret"
                            CredentialName = $_.displayName
                            CredentialId   = $_.keyId
                            StartDateTime  = $startdate
                            EndDateTime    = $enddate
                            DaysLeft       = $daysLeft
                            IsExpired      = ($daysLeft -lt 0)
                            Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le $Days) { "Warning" } else { "Valid" }
                        }
                        $credentialResults += $tempObj
                    }
                }
                else {
                    # Include all credentials (expired, expiring, and valid)
                    $tempObj = [PSCustomObject]@{
                        AppDisplayName = $app.displayName
                        AppId          = $app.appId
                        AppObjectId    = $app.id
                        CredentialType = "Client Secret"
                        CredentialName = $_.displayName
                        CredentialId   = $_.keyId
                        StartDateTime  = $startdate
                        EndDateTime    = $enddate
                        DaysLeft       = $daysLeft
                        IsExpired      = ($daysLeft -lt 0)
                        Status         = if ($daysLeft -lt 0) { "Expired" } elseif ($daysLeft -le 7) { "Critical" } elseif ($daysLeft -le 30) { "Warning" } else { "Valid" }
                    }
                    $credentialResults += $tempObj
                }
            }
        }
    }
}

Write-RjRbLog -Message "Processed $((($(($credentialResults) | Measure-Object).Count))) credentials" -Verbose

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

Write-Output "Exporting credentials..."

$reportFiles = @()
$xlsxPath = $null

if ((($(($credentialResults) | Measure-Object).Count) -gt 0)) {
    # Sort credentials by days left (ascending) to show most critical first
    $credentialResults = $credentialResults | Sort-Object DaysLeft

    # The report files are only needed when they will be uploaded and/or attached to an email
    if ($EmailTo -or $CreateDownloadLink) {
        if ($ReportFileFormat -ne 'XLSX only') {
            $credentialResults | Export-Csv -Path $credsCsv -NoTypeInformation -Encoding UTF8
            $reportFiles += $credsCsv
            Write-Verbose "Exported application credentials to: $credsCsv"
        }

        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxPath = $credsXlsx
            $credentialResults | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Expiring Credentials"
            $reportFiles += $xlsxPath
            Write-Verbose "Exported application credentials to: $xlsxPath"
        }
    }
}
else {
    Write-RjRbLog -Message "No credentials found matching the filter criteria" -Verbose
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
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
        Write-Output "No credentials found matching the filter criteria - skipping report upload."
    }
}

#endregion

########################################################
#region     Prepare Email Content
########################################################

Write-Output "Preparing email content..."

# Generate statistics
$totalCreds = (($(($credentialResults) | Measure-Object).Count))
$expiredCreds = (($(($credentialResults | Where-Object { $_.IsExpired }) | Measure-Object).Count))
$criticalCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired }) | Measure-Object).Count))
$warningCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Warning" }) | Measure-Object).Count))
$validCreds = (($(($credentialResults | Where-Object { $_.Status -eq "Valid" }) | Measure-Object).Count))
$secrets = (($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" }) | Measure-Object).Count))
$certs = (($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" }) | Measure-Object).Count))

# Create markdown content for email - different content based on mode
if ($listOnlyExpiring) {
    # EXPIRING MODE: Focus on urgency and action items (NO EXPIRED CREDENTIALS)
    $markdownContent = @"
# Application Credentials Expiry Alert

**Notice:** This report shows credentials that are **expiring within $Days days**.

## Action Required Summary

| Status | Count | Action Needed |
|--------|-------|---------------|
| **Critical (≤7 days)** | $($criticalCreds) | **URGENT** - Renew within 7 days |
| **Warning (≤$($Days) days)** | $($warningCreds) | **SOON** - Schedule renewal |
| **Total Requiring Attention** | **$($totalCreds)** | Review attached report file |

$(if ($criticalCreds -gt 0) {
@"
## CRITICAL - Expiring Within 7 Days ($($criticalCreds))

These credentials will expire very soon and require **urgent renewal**:

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired } | Select-Object -First 15 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | **$($_.DaysLeft)** |"
}) -join "`n")

$(if ($criticalCreds -gt 15) { "*... and $($criticalCreds - 15) more (see attached report file)*" })

**Action:** Schedule credential renewal within the next few days.

"@
})

$(if ($warningCreds -gt 0) {
@"
## WARNING - Expiring Within $($Days) Days ($($warningCreds))

These credentials should be renewed soon:

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Warning" } | Select-Object -First 15 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($warningCreds -gt 15) { "*... and $($warningCreds - 15) more (see attached report file)*" })

**Action:** Plan credential renewal within the next few weeks.

"@
})

## Next Steps

### Immediate Actions (Priority Order)

1. $(if ($criticalCreds -gt 0) { "**Renew $($criticalCreds) critical credential(s)** expiring within 7 days" } else { "No critical credentials expiring soon" })
2. $(if ($warningCreds -gt 0) { "**Schedule renewal for $($warningCreds) credential(s)** expiring within $($Days) days" } else { "No credentials in warning period" })

### Important Information

- **Credential Type Filter:** $($CredentialType)
- **Credential Types in Report:** $($secrets) Client Secrets, $($certs) Certificates
- **Filter Applied:** Showing only credentials expiring within $($Days) days (excluding already expired)
$(if ($ApplicationIdArray -and ($ApplicationIdArray.Count -gt 0)) { "- **Application Filter:** Limited to $($ApplicationIdArray.Count) specific application(s)" })
- **Note:** Already expired credentials are not included in this report

### Report File Details

The attached report file(s) contain complete information for all $($totalCreds) credentials requiring attention:
- Application details (Name, ID, Object ID)
- Credential type and name
- Exact expiration dates and days remaining
- Current status classification

**Use the report file(s) to prioritize your renewal tasks and track progress.**

---

*This email was automatically generated. Please do not reply to this email.*
"@
}
else {
    # ALL MODE: Comprehensive overview with statistics
    $markdownContent = @"
# Application Credentials Overview Report

This is a comprehensive inventory of **all** Application Registration credentials in your tenant.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Credentials** | $($totalCreds) |
| **Client Secrets** | $($secrets) |
| **Certificates** | $($certs) |
|  **Expired** | $($expiredCreds) |
|  **Critical (≤7 days)** | $($criticalCreds) |
|  **Warning (≤30 days)** | $($warningCreds) |
|  **Valid (>30 days)** | $($validCreds) |

$(if ($expiredCreds -gt 0) {
@"
## Expired Credentials ($($expiredCreds))

These credentials have already expired:

| Application | Credential Type | Name | Expired Since |
|-------------|----------------|------|---------------|
$(($credentialResults | Where-Object { $_.IsExpired } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $(([Math]::Abs($_.DaysLeft))) days ago |"
}) -join "`n")

$(if ($expiredCreds -gt 10) { "*... and $($expiredCreds - 10) more (see attached report file)*" })


"@
})

$(if ($criticalCreds -gt 0) {
@"
## Critical - Expiring Soon (≤7 days) ($($criticalCreds))

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Critical" -and -not $_.IsExpired } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($criticalCreds -gt 10) { "*... and $($criticalCreds - 10) more (see attached report file)*" })


"@
})

$(if ($warningCreds -gt 0) {
@"
## Warning - Expiring Soon (≤30 days) ($($warningCreds))

| Application | Credential Type | Name | Days Left |
|-------------|----------------|------|-----------|
$(($credentialResults | Where-Object { $_.Status -eq "Warning" } | Select-Object -First 10 | ForEach-Object {
    "| $($_.AppDisplayName) | $($_.CredentialType) | $($_.CredentialName) | $($_.DaysLeft) |"
}) -join "`n")

$(if ($warningCreds -gt 10) { "*... and $($warningCreds - 10) more (see attached report file)*" })


"@
})

## Credential Health Overview

### Current Status

- **Healthy:** $($validCreds) credentials with >30 days remaining
- **Attention Needed:** $($expiredCreds + $criticalCreds + $warningCreds) credentials require action
- **Success Rate:** $(if ($totalCreds -gt 0) { [math]::Round(($validCreds / $totalCreds) * 100, 1) } else { 0 })% of credentials are in good standing

### Breakdown by Type

- **Client Secrets:** $($secrets) total
  - Expired: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" -and $_.IsExpired }) | Measure-Object).Count))
  - Expiring Soon: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Client Secret" -and ($_.Status -eq "Critical" -or $_.Status -eq "Warning") }) | Measure-Object).Count))

- **Certificates:** $($certs) total
  - Expired: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" -and $_.IsExpired }) | Measure-Object).Count))
  - Expiring Soon: $(($(($credentialResults | Where-Object { $_.CredentialType -eq "Certificate" -and ($_.Status -eq "Critical" -or $_.Status -eq "Warning") }) | Measure-Object).Count))

## Recommendations

### Immediate Actions

$(if ($expiredCreds -gt 0) {
"- **$($expiredCreds) expired credential(s)** - Review and renew or remove if no longer needed"
} else {
"- No expired credentials found"
})

$(if ($criticalCreds -gt 0) {
"- **$($criticalCreds) critical credential(s) expiring within 7 days** - Schedule urgent renewal"
})

$(if ($warningCreds -gt 0) {
"- **$($warningCreds) credential(s) expiring within 30 days** - Plan renewal activities"
})

### Best Practices

- **Regular Rotation:** Rotate credentials every 6-12 months according to your security policy
- **Automation:** Set up automated alerts for credentials expiring within 30 days
- **Certificate Preference:** Consider migrating to certificate-based authentication where possible
- **Documentation:** Maintain a credential renewal schedule and document processes
- **Cleanup:** Remove unused or expired credentials to reduce security risks
- **Monitoring:** Review this report monthly to maintain credential health

## Data Export Information

The attached report file(s) contain the complete inventory of all $($totalCreds) credentials:

- **Credential Type Filter:** $($CredentialType)
- Application Display Name and ID
- Credential Type (Client Secret or Certificate)
- Credential Name and ID
- Start and End DateTime
- Days remaining until expiry
- Current status classification (Expired, Critical, Warning, Valid)

**Use this data for:**
- Credential lifecycle management
- Compliance reporting
- Renewal planning and tracking
- Security audits

---

*This email was automatically generated. Please do not reply to this email.*
"@
}

#endregion

########################################################
#region     Send Email Report (if EmailTo is provided)
########################################################

if ($EmailTo) {
    Write-Output "Sending email report..."
    Write-Output ""

    $dateStr = Get-Date -Format 'yyyy-MM-dd'
    $emailSubject = if ($listOnlyExpiring) {
        "Credentials Expiring Alert (≤$($Days) days) - $($tenantDisplayName) - $($dateStr)"
    }
    else {
        "Application Credentials Inventory - $($tenantDisplayName) - $($dateStr)"
    }

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

    try {
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# $(if ($listOnlyExpiring) { "Application Credentials Expiry Alert" } else { "Application Credentials Overview Report" })

## Summary

| Metric | Count |
|--------|-------|
| **Total Credentials** | $($totalCreds) |
| **Client Secrets** | $($secrets) |
| **Certificates** | $($certs) |
| **Critical (≤7 days)** | $($criticalCreds) |
| **Warning** | $($warningCreds) |

## Data Files

- **$(Split-Path $xlsxPath -Leaf)**: Formatted Excel workbook with the complete credential list

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
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams
            Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        }

        if ($listOnlyExpiring) {
            Write-Output "Application Credentials Expiry Alert sent successfully"
            Write-Output "Mode: EXPIRING ONLY (≤$($Days) days)"
        }
        else {
            Write-Output "Application Credentials Inventory Report sent successfully"
            Write-Output "Mode: ALL CREDENTIALS"
        }

        Write-Output "Recipient: $($EmailTo)"
        Write-Output "Total Credentials: $($totalCreds)"

        if ($listOnlyExpiring) {
            Write-Output "Requiring Attention: Expired: $($expiredCreds) | Critical: $($criticalCreds) | Warning: $($warningCreds)"
        }
        else {
            Write-Output "Status: Valid: $($validCreds) | Warning: $($warningCreds) | Critical: $($criticalCreds) | Expired: $($expiredCreds)"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

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

# Clean up temporary report files (covers the email and the download-link-only case)
foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Cleaned up report file: $($reportFilePath)" -Verbose
        }
        catch {
            Write-RjRbLog -Message "Warning: Could not clean up report file '$($reportFilePath)': $($_.Exception.Message)" -Verbose
        }
    }
}

Write-RjRbLog -Message "Application Credentials Expiry email report completed successfully" -Verbose

#endregion
