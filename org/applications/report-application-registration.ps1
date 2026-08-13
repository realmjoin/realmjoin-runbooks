<#
    .SYNOPSIS
    Generate and email a comprehensive Application Registration report

    .DESCRIPTION
    This runbook generates a report of all application registrations in Microsoft Entra ID and can optionally include deleted registrations.
    It exports the results to CSV files and an Excel (xlsx) workbook and can send them via email.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachments exceed the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.
    Use it for periodic inventory, review, and audit purposes.

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

    .PARAMETER IncludeDeletedApps
    Whether to include deleted application registrations in the report (default: true)

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
            "IncludeDeletedApps": {
                "DisplayName": "Include Deleted Applications"
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
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
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

    [bool]$IncludeDeletedApps = $true,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-application-registration",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
}
Write-RjRbLog -Message "Include Deleted Apps: $IncludeDeletedApps" -Verbose
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

if ($IncludeDeletedApps -notin $true, $false) {
    Write-RjRbLog -Message "Invalid value for IncludeDeletedApps. Please specify true or false." -Verbose
    throw "Invalid value for IncludeDeletedApps. Please specify true or false."
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Email Function Definitions
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

Write-Output "Preparing temporary directory for CSV files..."
# Create temporary directory for CSV files
$tempDir = Join-Path (Get-Location).Path "AppRegReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

#endregion

########################################################
#region     Get App Registrations
########################################################

Write-Output "Retrieving all App Registrations..."

$allAppRegs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
Write-Output "Found $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..."

$appRegResults = @()
$processedCount = 0

foreach ($appReg in $allAppRegs) {
    $processedCount++
    if ($processedCount % 50 -eq 0) {
        Write-RjRbLog -Message "Processed $processedCount of $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..." -Verbose
    }

    # Create standardized object
    $tempObj = [PSCustomObject]@{
        AppId             = $appReg.appId
        AppRegObjectId    = $appReg.id
        DisplayName       = $appReg.displayName
        CreatedDateTime   = $appReg.createdDateTime
        PublisherDomain   = $appReg.publisherDomain
        SignInAudience    = $appReg.signInAudience
        AppRegPortalLink  = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($appReg.appId)"
        AccountEnabled    = $false
        TenantId          = $tenantId
        IsDeleted         = $false
        HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
        HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
        SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
        CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
    }

    # Get associated Service Principal
    try {
        $spnUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($appReg.appId)'"
        $spnResponse = Invoke-MgGraphRequest -Uri $spnUri -Method GET -ErrorAction SilentlyContinue

        if ($spnResponse.value -and (($(($spnResponse.value) | Measure-Object).Count) -gt 0)) {
            $spn = $spnResponse.value[0]
            $tempObj.SpnObjectId = $spn.id
            $tempObj.SpnPortalLink = "https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($spn.id)/appId/$($appReg.appId)"
            $tempObj.AccountEnabled = $spn.accountEnabled
        }
    }
    catch {
        Write-RjRbLog -Message "Could not retrieve Service Principal for App: $($appReg.displayName)" -Verbose
    }

    $appRegResults += $tempObj
}

Write-RjRbLog -Message "Processed all $((($(($appRegResults) | Measure-Object).Count))) App Registrations" -Verbose

#endregion

########################################################
#region     Get Deleted App Registrations (if requested)
########################################################

$deletedAppRegResults = @()

if ($IncludeDeletedApps) {
    Write-Output "Retrieving deleted App Registrations..."

    try {
        $deletedAppRegs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application"
        Write-Output "Found $((($(($deletedAppRegs) | Measure-Object).Count))) deleted App Registrations"

        foreach ($appReg in $deletedAppRegs) {
            $tempObj = [PSCustomObject]@{
                AppId             = $appReg.appId
                AppRegObjectId    = $appReg.id
                DisplayName       = $appReg.displayName
                CreatedDateTime   = $appReg.createdDateTime
                DeletedDateTime   = $appReg.deletedDateTime
                PublisherDomain   = $appReg.publisherDomain
                SignInAudience    = $appReg.signInAudience
                AppRegPortalLink  = "" # Not accessible for deleted apps
                AccountEnabled    = $false
                TenantId          = $tenantId
                IsDeleted         = $true
                HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
                HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
                SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
                CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
            }

            $deletedAppRegResults += $tempObj
        }

        Write-RjRbLog -Message "Processed $((($(($deletedAppRegResults) | Measure-Object).Count))) deleted App Registrations" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Warning: Could not retrieve deleted App Registrations: $($_.Exception.Message)" -Verbose
    }
}

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

$reportFiles = @()
$xlsxPath = $null

if ($EmailTo -or $CreateDownloadLink) {
    if ($ReportFileFormat -ne 'XLSX only') {
        # Export active App Registrations
        $activeAppRegCsv = Join-Path $tempDir "AppRegistrations_Active.csv"
        $appRegResults | Export-Csv -Path $activeAppRegCsv -NoTypeInformation -Encoding UTF8
        $reportFiles += $activeAppRegCsv
        Write-Verbose "Exported active App Registrations to: $activeAppRegCsv"

        # Export deleted App Registrations (if any)
        if ((($(($deletedAppRegResults) | Measure-Object).Count) -gt 0)) {
            $deletedAppRegCsv = Join-Path $tempDir "AppRegistrations_Deleted.csv"
            $deletedAppRegResults | Export-Csv -Path $deletedAppRegCsv -NoTypeInformation -Encoding UTF8
            $reportFiles += $deletedAppRegCsv
            Write-Verbose "Exported deleted App Registrations to: $deletedAppRegCsv"
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet
        $xlsxPath = Join-Path $tempDir "AppRegistrations.xlsx"
        $workbookCoverSheet = [ordered]@{
            Title                       = 'Application Registration Report'
            Generated                   = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'           = $Version
            'Active App Registrations'  = ($appRegResults | Measure-Object).Count
            'Deleted App Registrations' = ($deletedAppRegResults | Measure-Object).Count
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Active' = $appRegResults; 'Deleted' = $deletedAppRegResults }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
        Write-Verbose "Exported App Registrations workbook to: $xlsxPath"
    }
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
        Write-Output "No report files were generated - skipping report upload."
    }
}

#endregion

########################################################
#region     Prepare Email Content
########################################################

Write-Output "Preparing email content..."
# Generate statistics
$activeAppsWithSecrets = (($(($appRegResults | Where-Object { $_.HasSecrets }) | Measure-Object).Count))
$activeAppsWithCerts = (($(($appRegResults | Where-Object { $_.HasCertificates }) | Measure-Object).Count))
$enabledApps = (($appRegResults | Where-Object { $_.AccountEnabled }) | Measure-Object).Count

# Create markdown content for email
$markdownContent = @"
# Application Registration Report

This report provides a comprehensive overview of all Application Registrations in your Entra ID.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Active App Registrations** | $($appRegResults.Count) |
| **Deleted App Registrations** | $($deletedAppRegResults.Count) |
| **Enabled Service Principals** | $($enabledApps) |
| **Apps with Client Secrets** | $($activeAppsWithSecrets) |
| **Apps with Certificates** | $($activeAppsWithCerts) |

## Report Details

### Active Application Registrations
$(if ($ReportFileFormat -ne 'XLSX only') { "- **File:** AppRegistrations_Active.csv" })
- **Count:** $($appRegResults.Count) applications
- Contains all currently active App Registrations with their associated Service Principals

$(if ($deletedAppRegResults.Count -gt 0) {
@"

### Deleted Application Registrations
$(if ($ReportFileFormat -ne 'XLSX only') { "- **File:** AppRegistrations_Deleted.csv" })
- **Count:** $($deletedAppRegResults.Count) applications
- Contains App Registrations that have been deleted but are still recoverable
"@
} else {
"### Deleted Application Registrations
No deleted App Registrations found in the tenant."
})

$(if ($ReportFileFormat -ne 'CSV only') {
@"

### Excel Workbook
- **File:** AppRegistrations.xlsx
- Contains the Active and Deleted lists as separate worksheets in a formatted Excel workbook
"@
})

## Security Recommendations

### Applications with Client Secrets
$($activeAppsWithSecrets) applications have client secrets configured. Please review these regularly:
- Ensure secrets are rotated according to your security policy
- Remove unused secrets to reduce attack surface
- Consider migrating to certificate-based authentication where possible

### Applications with Certificates
$($activeAppsWithCerts) applications use certificate-based authentication:
- Monitor certificate expiration dates
- Ensure certificates are stored securely
- Have a renewal process in place

## Data Export Information

The attached report file(s) contain detailed information including:
- Application ID and Object ID
- Display Name and Creation Date
- Publisher Domain and Sign-in Audience
- Authentication method details (secrets/certificates)
- Direct links to Azure Portal for management

---

*This email was automatically generated. Please do not reply to this email.*
"@

#endregion

########################################################
#region     Send Email Report (if EmailTo is provided)
########################################################

$brandingMailParams = @{}
if ($EmailTo) {
    Write-Output "Send email report..."
    Write-Output ""

    $emailSubject = "App Registration Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
    try {
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Application Registration Report

This report provides a comprehensive overview of all Application Registrations in your Entra ID.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Active App Registrations** | $($appRegResults.Count) |
| **Deleted App Registrations** | $($deletedAppRegResults.Count) |
| **Enabled Service Principals** | $($enabledApps) |
| **Apps with Client Secrets** | $($activeAppsWithSecrets) |
| **Apps with Certificates** | $($activeAppsWithCerts) |

## Data Files

- **AppRegistrations.xlsx**: Excel workbook with the Active and Deleted lists (one worksheet per dataset)

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV files.

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

        Write-Output "✅ App Registration report generated and sent successfully"
        Write-Output "📧 Recipient: $($EmailTo)"
        Write-Output "📊 Active Apps: $($appRegResults.Count)"
        Write-Output "🗑️ Deleted Apps: $($deletedAppRegResults.Count)"
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

# Clean up temporary files
try {
    Remove-Item -Path $tempDir -Recurse -Force
    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
}
catch {
    Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
}

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-RjRbLog -Message "App Registration email report completed successfully" -Verbose

#endregion