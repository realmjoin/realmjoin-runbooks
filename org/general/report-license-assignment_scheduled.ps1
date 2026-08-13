<#
	.SYNOPSIS
	Generate and email a license availability report based on thresholds

    .DESCRIPTION
    This runbook checks the license availability based on the transmitted SKUs and sends an email report if any thresholds are reached.
    Two types of thresholds can be configured. The first type is a minimum threshold, which triggers an alert when the number of available licenses falls below a specified number.
    The second type is a maximum threshold, which triggers an alert when the number of available licenses exceeds a specified number.
    The report includes detailed information about licenses that are outside the configured thresholds, exports them to CSV and/or Excel (xlsx) files, and sends them via email.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .PARAMETER InputJson
    JSON array containing SKU configurations with thresholds. Each entry should include a SKUPartNumber for the Microsoft SKU identifier, a FriendlyName as the display name for the license, an optional MinThreshold specifying the minimum number of licenses that should be available, and an optional MaxThreshold specifying the maximum number of licenses that should be available.

    This needs to be configured in the runbook customization

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

	.PARAMETER EmailFrom
	Sender email address resolved from settings.

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
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

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
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

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
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
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
