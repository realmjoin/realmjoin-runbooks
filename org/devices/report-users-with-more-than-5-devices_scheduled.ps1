<#
    .SYNOPSIS
    Report users with more than five registered devices

    .DESCRIPTION
    This runbook queries Entra ID devices and their registered users to identify users with more than five devices.
    It outputs a summary table and can optionally send an email with the report attached as CSV files and/or as an Excel workbook (one worksheet for the summary, one for the details).
    The detailed export lists each device with its object ID, Entra ID device ID and display name, and indicates whether the device is also present in Intune as a managed device and whether it is compliant (both highlighted green/red in the Excel workbook).
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachments exceed the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

.PARAMETER IntuneOnlyDevices
    If enabled, only devices that are present in Intune (managed devices) are considered for the report.
    The "InIntune" column is omitted from the detailed CSV export in this case, as all reported devices are Intune-managed.
    Disabled by default.

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

.PARAMETER CallerName
    Caller name for auditing purposes.

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "IntuneOnlyDevices": {
                "DisplayName": "Only include devices present in Intune"
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
    [bool]$IntuneOnlyDevices = $false,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "users-with-more-than-5-devices",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string]$BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string]$BrandingFooterLink,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.10.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "IntuneOnlyDevices: $IntuneOnlyDevices" -Verbose

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

####################################################################
#region Function Definitions
####################################################################
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

####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

####################################################################
#region Get all devices based on registered users
####################################################################

Write-Output "Querying devices..."
Write-Output "  Note: Depending on the number of devices in the tenant, this process can take several minutes!"
$property = 'id,deviceId,displayName,isCompliant,registeredUsers'

$AllDevices_BasedOnUsers = @()
$uri = "https://graph.microsoft.com/v1.0/devices?`$select=$property&`$expand=registeredUsers"

$AllDevices_BasedOnUsers = Get-GraphPagedResult -Uri $uri

Write-Output "  Retrieved $($AllDevices_BasedOnUsers.Count) devices from the tenant."

# Retrieve all Intune managed devices to determine Intune presence per device (and to filter, if requested)
Write-Output "Querying Intune managed devices..."
$intuneManagedDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=azureADDeviceId"
$intuneDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($managedDevice in $intuneManagedDevices) {
    if ($managedDevice.azureADDeviceId) {
        [void]$intuneDeviceIds.Add([string]$managedDevice.azureADDeviceId)
    }
}
Write-Output "  Retrieved $($($intuneManagedDevices | Measure-Object).Count) managed devices from Intune."

if ($IntuneOnlyDevices) {
    $AllDevices_BasedOnUsers = $AllDevices_BasedOnUsers | Where-Object { $_.deviceId -and $intuneDeviceIds.Contains([string]$_.deviceId) }
    Write-Output "  Only devices present in Intune are considered: $($($AllDevices_BasedOnUsers | Measure-Object).Count) devices remain."
}

$raw = $AllDevices_BasedOnUsers | Where-Object { $_.RegisteredUsers.Count -gt 0 } | Group-Object { $_.RegisteredUsers.Id } | Where-Object Count -GT 5

#endregion

####################################################################
#region Prepare output
####################################################################

# Prepare output. Should contain the user ID, the UPN, and the number of devices
$Output = @()

foreach ($group in $raw) {
    $objectId = $group.Name
    $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
    $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName
    $deviceCount = $group.Count

    $Output += [PSCustomObject]@{
        ObjectId    = $objectId
        DisplayName = $displayName
        UPN         = $upn
        DeviceCount = $deviceCount
    }
}

Write-Output ""
if ($($Output | Measure-Object).Count -eq 0) {
    Write-Output "No users found with more than five devices."
}
else {
    Write-Output "Found $($($Output | Measure-Object).Count) users with more than five devices:"
    $Output | Sort-Object DeviceCount -Descending | Format-Table
}

#endregion

######################################################################
#region Report File Export (if needed for download link or email)
######################################################################

$totalUsers = ($Output | Measure-Object).Count
$reportFiles = @()
$xlsxFile = $null
$tempDir = $null
$detailedOutput = @()
$fileName_Summary = "UsersWithMoreThan5Devices_Summary.csv"
$fileName_Details = "UsersWithMoreThan5Devices_Details.csv"
$fileName_Workbook = "UsersWithMoreThan5Devices.xlsx"

if (($CreateDownloadLink -or $EmailTo) -and $totalUsers -gt 0) {
    Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing report file export" -Verbose

    # Create temporary directory for report files
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "UsersWithMultipleDevicesReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    $summaryOutput = $Output | Sort-Object DeviceCount -Descending

    # Create detailed device list for each user
    foreach ($group in $raw) {
        $objectId = $group.Name
        $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
        $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName

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

    if ($ReportFileFormat -ne 'XLSX only') {
        # Export summary to CSV
        $csvFile = Join-Path $tempDir $fileName_Summary
        $summaryOutput | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported summary data to: $csvFile"
        $reportFiles += $csvFile

        # Export detailed device list to CSV
        $detailedCsvFile = Join-Path $tempDir $fileName_Details
        $detailedOutput | Export-Csv -Path $detailedCsvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported detailed device data to: $detailedCsvFile"
        $reportFiles += $detailedCsvFile
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # Export both datasets into a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet.
        # The InIntune and Compliant columns are highlighted green/red; when IntuneOnlyDevices omits the InIntune column, its rules are skipped.
        $xlsxFile = Join-Path $tempDir $fileName_Workbook
        $workbookCoverSheet = [ordered]@{
            Title                = 'Users with More Than 5 Devices'
            Generated            = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'    = $Version
            Scope                = if ($IntuneOnlyDevices) { 'Only devices present in Intune' } else { 'All Entra ID devices' }
            'Users (>5 devices)' = $totalUsers
            'Device entries'     = ($detailedOutput | Measure-Object).Count
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Summary' = $summaryOutput; 'Details' = $detailedOutput }) -Path $xlsxFile -CoverSheet $workbookCoverSheet -HighlightRules @(
            @{ Column = 'InIntune'; Value = 'yes'; Color = 'Green' }
            @{ Column = 'InIntune'; Value = 'no'; Color = 'Red' }
            @{ Column = 'Compliant'; Value = 'yes'; Color = 'Green' }
            @{ Column = 'Compliant'; Value = 'no'; Color = 'Red' }
        )
        Write-Verbose "Exported summary and detailed data to: $xlsxFile"
        $reportFiles += $xlsxFile
    }
}

#endregion

######################################################################
#region Upload / Download Link (if CreateDownloadLink is enabled)
######################################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "Uploading report files to storage account..."

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
        Write-Output "No users with more than five devices were found - skipping report upload."
    }
}

#endregion

######################################################################
#region Send Email Report (if requested)
######################################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

    # Get tenant information
    try {
        $tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
        if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
            $tenant = $tenant.value[0]
        }
        $tenantDisplayName = $tenant.displayName
        $tenantId = $tenant.id
        Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose
    }
    catch {
        Write-Warning "Warning: Could not retrieve tenant information: $($_.Exception.Message) - proceeding without tenant name."
        $tenantDisplayName = ""
    }

    if ($totalUsers -eq 0) {
        # No users found - send email without attachments
        Write-RjRbLog -Message "No users found with more than 5 devices - sending notification email" -Verbose

        $markdownContent = @"
# Users with More Than 5 Devices Report

## Summary

✅ **Good News!** No users were found with more than 5 devices registered in Entra ID.
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
        $totalDevices = ($detailedOutput | Measure-Object).Count
        $avgDevicesPerUser = if ($totalUsers -gt 0) { [math]::Round($totalDevices / $totalUsers, 2) } else { 0 }
        $maxDevices = ($Output | Measure-Object -Property DeviceCount -Maximum).Maximum
        $minDevices = ($Output | Measure-Object -Property DeviceCount -Minimum).Minimum

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
    $Output | Sort-Object DeviceCount -Descending | Select-Object -First 20 | ForEach-Object {
        "| $($_.DisplayName) | $($_.UPN) | $($_.DeviceCount) |"
    }
)

## Report Details

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Summary)**: Summary of $($totalUsers) users with their device counts (CSV)" })
$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Details)**: Detailed device information for each user, $($totalDevices) device entries (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_Workbook)**: Both datasets as separate worksheets (`"Summary`" and `"Details`") in an Excel workbook" })

## Recommendations

### Device Management Best Practices

🔍 **Review Device Assignments:**
- Users with many devices may have old/inactive devices registered
- Consider implementing a device cleanup policy
- Review if all devices are actively used

🛡️ **Security Considerations:**
- Multiple devices increase the attack surface
- Ensure all devices comply with security policies
- Verify that unused devices are properly decommissioned

📋 **Compliance & Licensing:**
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
- **Summary:** User Object ID, Display Name, UPN, and Device Count
- **Details:** Complete device list for each user including the device object ID, the Entra ID device ID and the device name$(if (-not $IntuneOnlyDevices) { ", plus an ""InIntune"" column indicating whether the device is present in Intune" }), plus a ""Compliant"" column indicating the device compliance state (yes/no/unknown)
$(if ($ReportFileFormat -ne 'CSV only') { "- **Excel Workbook:** Both datasets in one file, one worksheet each" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Users with More Than 5 Devices Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"
    }

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

    try {
        if ($reportFiles.Count -gt 0) {
            Write-RjRbLog -Message "Sending email with $($reportFiles.Count) attachment(s)" -Verbose

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

- **$($fileName_Workbook)**: Excel workbook with both datasets as separate worksheets (`"Summary`" and `"Details`")

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
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile) {
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbGuardedReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Write-RjRbLog -Message "Sending email without attachments" -Verbose
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
            Write-Output "Email report sent successfully to: $($EmailTo)"
        }

        Write-Output "✅ Report generated and sent successfully"
        Write-Output "📧 Recipient: $($EmailTo)"
        if ($totalUsers -gt 0) {
            Write-Output "👥 Users reported: $totalUsers"
            Write-Output "📱 Total devices: $($detailedOutput.Count)"
        }
        else {
            Write-Output "✅ No users with more than 5 devices found"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
    finally {
        # Clean up temporary files (only if they were created)
        if ($totalUsers -gt 0) {
            try {
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force
                    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
                }
            }
            catch {
                Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
            }
        }
    }
}

#endregion

######################################################################
#region Cleanup
######################################################################
# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

# Cleanup temporary files (covers the download-link-only case; the email path cleans up in its finally block)
if ($tempDir -and (Test-Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
}

#endregion