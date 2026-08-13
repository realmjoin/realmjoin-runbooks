<#
    .SYNOPSIS
    Create a temporary access pass for a user

    .DESCRIPTION
    Creates a new Temporary Access Pass (TAP) authentication method for a user in Microsoft Entra ID. Existing TAPs for the user are removed before creating a new one. Optionally sends a notification email to the user's primary email address informing them about the newly created TAP. The email language is automatically determined by the user's usage location.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER LifetimeInMinutes
    Lifetime of the temporary access pass in minutes. Valid values are between 60 and 480 minutes (1-8 hours).

    .PARAMETER OneTimeUseOnly
    If set to true, the pass can be used only once.

    .PARAMETER NotifyUser
    If enabled, sends a notification email to the user's primary email address about the newly created TAP.

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

    .PARAMETER ServiceDeskDisplayName
    Service Desk display name for user contact information (optional).

    .PARAMETER ServiceDeskEmail
    Service Desk email address for user contact information (optional).

    .PARAMETER ServiceDeskPhone
    Service Desk phone number for user contact information (optional).

    .PARAMETER ServiceDeskPortalUrl
    Service Desk portal URL for user contact information, rendered as a clickable link (optional).

    .PARAMETER ServiceDeskTicketUrl
    Direct link to the Service Desk ticket related to this request, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "NotifyUser": {
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
            "ServiceDeskDisplayName": {
                "Hide": true
            },
            "ServiceDeskEmail": {
                "Hide": true
            },
            "ServiceDeskPhone": {
                "Hide": true
            },
            "ServiceDeskPortalUrl": {
                "Hide": true
            },
            "ServiceDeskTicketUrl": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number -DisplayName "Lifetime (minutes)" } )]
    [ValidateRange(60, 480)]
    [int] $LifetimeInMinutes = 240,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number -DisplayName "One time use only" } )]
    [bool] $OneTimeUseOnly = $true,
    [bool] $NotifyUser = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string] $BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string] $BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string] $BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_DisplayName" } )]
    [string] $ServiceDeskDisplayName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_EMail" } )]
    [string] $ServiceDeskEmail,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_Phone" } )]
    [string] $ServiceDeskPhone,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_PortalUrl" } )]
    [string] $ServiceDeskPortalUrl,
    [string] $ServiceDeskTicketUrl = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "LifetimeInMinutes: $LifetimeInMinutes" -Verbose
Write-RjRbLog -Message "OneTimeUseOnly: $OneTimeUseOnly" -Verbose
Write-RjRbLog -Message "NotifyUser: $NotifyUser" -Verbose
Write-RjRbLog -Message "ServiceDeskDisplayName: $ServiceDeskDisplayName" -Verbose
Write-RjRbLog -Message "ServiceDeskEmail: $ServiceDeskEmail" -Verbose
Write-RjRbLog -Message "ServiceDeskPhone: $ServiceDeskPhone" -Verbose
Write-RjRbLog -Message "ServiceDeskPortalUrl: $ServiceDeskPortalUrl" -Verbose
Write-RjRbLog -Message "ServiceDeskTicketUrl: $ServiceDeskTicketUrl" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
#
############################################################

if ($LifetimeInMinutes -lt 60 -or $LifetimeInMinutes -gt 480) {
    Write-Error -Message "Invalid LifetimeInMinutes specified: $LifetimeInMinutes. The valid range is between 60 and 480 minutes." -ErrorAction Continue
    throw "Invalid LifetimeInMinutes: $LifetimeInMinutes. Valid range: 60-480."
}

if ($NotifyUser) {
    if (-not $EmailFrom) {
        Write-Warning "The sender email address is required when NotifyUser is enabled. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
        throw "EmailFrom is not configured in runbook customization."
    }
}

#endregion Parameter Validation

############################################################
#region     Email Branding Function
#
############################################################

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

#endregion Email Branding Function

############################################################
#region     Connect Part
#
############################################################

Connect-RjRbGraph

#endregion Connect Part

############################################################
#region     StatusQuo & Preflight-Check Part
#
############################################################

"## Trying to create a Temp. Access Pass (TAP) for user '$UserName'"

# Retrieve user details for email notification
try {
    $userDetails = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -OdSelect "mail,userPrincipalName,usageLocation"
    $userEmail = if ($userDetails.mail) { $userDetails.mail } else { $userDetails.userPrincipalName }
    $userLanguage = if ($userDetails.usageLocation -eq "DE") { "DE" } else { "EN" }
    Write-RjRbLog -Message "User email: $userEmail, Usage location: $($userDetails.usageLocation), Language: $userLanguage" -Verbose
}
catch {
    Write-Warning "Could not retrieve user details. Falling back to UPN as email and English language."
    $userEmail = $UserName
    $userLanguage = "EN"
}

try {
    # Making sure no old temp. access passes exist for the user
    $oldPasses = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Beta
    $oldPasses | ForEach-Object {
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods/$($_.id)" -Beta -Method Delete | Out-Null
    }
}
catch {
    "Querying of existing Temp. Access Passes failed. Maybe you are missing Graph API permissions:"
    "- 'UserAuthenticationMethod.ReadWrite.All' (API)"
    throw ($_)
}

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

try {
    # Creating new temp. access pass
    $body = @{
        "@odata.type"       = "#microsoft.graph.temporaryAccessPassAuthenticationMethod"
        "lifetimeInMinutes" = $LifetimeInMinutes
        "isUsableOnce"      = $OneTimeUseOnly
    }
    $pass = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Body $body -Beta -Method Post

    if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
        "## Beware: The use of Temporary access passes seems to be disabled for this user."
        ""
    }

    "## New Temporary access pass for '$UserName' with a lifetime of $LifetimeInMinutes minutes has been created:"
    ""
    "$($pass.temporaryAccessPass)"
}
catch {
    "Creation of a new Temp. Access Pass failed. Maybe you are missing Graph API permissions:"
    "- 'UserAuthenticationMethod.ReadWrite.All' (API)"
    throw ($_)
}

    #region Email Notification
    ##############################

    $brandingMailParams = @{}
    if ($NotifyUser) {
        # Build Service Desk contact information section
        $serviceDeskSection = ""
        if ($ServiceDeskDisplayName -or $ServiceDeskEmail -or $ServiceDeskPhone -or $ServiceDeskPortalUrl -or $ServiceDeskTicketUrl) {
            if ($userLanguage -eq "DE") {
                $serviceDeskSection = "`n`n---`n`n### Service Desk Kontaktinformationen`n"
            }
            else {
                $serviceDeskSection = "`n`n---`n`n### Service Desk Contact Information`n"
            }
            if ($ServiceDeskDisplayName) {
                $serviceDeskSection += "`n$($ServiceDeskDisplayName)"
            }
            if ($ServiceDeskEmail) {
                $serviceDeskSection += "`n**Email:** [$($ServiceDeskEmail)](mailto:$($ServiceDeskEmail))"
            }
            if ($ServiceDeskPhone) {
                if ($userLanguage -eq "DE") {
                    $serviceDeskSection += "`n**Telefon:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
                }
                else {
                    $serviceDeskSection += "`n**Phone:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
                }
            }
            if ($ServiceDeskPortalUrl) {
                $serviceDeskSection += "`n**Portal:** [$($ServiceDeskPortalUrl)]($($ServiceDeskPortalUrl))"
            }
            if ($ServiceDeskTicketUrl) {
                $serviceDeskSection += "`n**Ticket:** [$($ServiceDeskTicketUrl)]($($ServiceDeskTicketUrl))"
            }
        }

        # Build email content based on user's usage location
        if ($userLanguage -eq "DE") {
            $emailSubject = "Ein Temporary Access Pass wurde für Ihr Konto erstellt"
            $markdownContent = @"
# Temporary Access Pass

Hallo,

für Ihr Konto **$UserName** wurde ein neuer **Temporary Access Pass (TAP)** erstellt. Dieser ist **$LifetimeInMinutes Minuten** gültig und kann zur Anmeldung an Ihrem Konto verwendet werden.

Falls Sie davon nichts wissen oder nicht eingebunden waren, wenden Sie sich bitte umgehend an Ihren IT Support.$($serviceDeskSection)

---

*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*
"@
        }
        else {
            $emailSubject = "A Temporary Access Pass has been created for your account"
            $markdownContent = @"
# Temporary Access Pass

Hello,

a new **Temporary Access Pass (TAP)** has been created for your account **$UserName**. This pass is valid for **$LifetimeInMinutes minutes** and can be used to sign in to your account.

If you are not aware of this or were not involved, please contact your IT support immediately.$($serviceDeskSection)

---

*This email was automatically generated. Please do not reply to this email.*
"@
        }

        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

        try {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $userEmail -Subject $emailSubject -MarkdownContent $markdownContent -ReportVersion $Version @brandingMailParams
            ""
            "## Notification email sent to '$userEmail'."
        }
        catch {
            Write-Warning "Failed to send notification email to '$userEmail': $($_.Exception.Message)"
        }
    }

    #endregion Email Notification

#endregion Main Part

""
"## Done!"