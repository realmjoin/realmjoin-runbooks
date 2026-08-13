<#
    .SYNOPSIS
    List all MFA / authentication methods of a user

    .DESCRIPTION
    Retrieves and displays every Microsoft Entra ID authentication method registered for a target user, including phone numbers for phone-based methods. Phone numbers can optionally be masked, showing only the last four digits. Optionally a notification email can be sent to the user informing them that their MFA methods have been retrieved through this runbook.

    .PARAMETER UserName
    User Principal Name of the target user. Auto-filled by the RealmJoin portal in the user context.

    .PARAMETER NotifyUser
    When enabled, sends a notification email to the target user informing them that their MFA methods were retrieved by an administrator. Default is disabled.

    .PARAMETER MaskPhoneNumbers
    When enabled, all phone numbers are masked except for the last four digits (for example +491234567890 becomes ********7890). Default is disabled.

    .PARAMETER EmailFrom
    Sender email address for the optional notification mail. Sourced from the RealmJoin tenant setting RJReport.EmailSender.

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
    Service Desk display name for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_DisplayName.

    .PARAMETER ServiceDeskEmail
    Service Desk email address for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_EMail.

    .PARAMETER ServiceDeskPhone
    Service Desk phone number for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_Phone.

    .PARAMETER ServiceDeskPortalUrl
    Service Desk portal URL for user contact information, rendered as a clickable link (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_PortalUrl.

    .PARAMETER ServiceDeskTicketUrl
    Direct link to the Service Desk ticket related to this request, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

    .PARAMETER LanguageOverride
    Overrides the language used for the notification email. Accepted values are 'DE' (German) or 'EN' (English). If left empty, the language is determined automatically based on the target user's usage location.

    .PARAMETER CallerName
    Caller name for auditing purposes. Auto-filled by the RealmJoin portal.

    .NOTES
    Permissions (managed identity, application):
    - UserAuthenticationMethod.Read.All - list authentication methods
    - User.Read.All                      - resolve target user
    - Organization.Read.All              - read tenant display name for the email body
    - Mail.Send                          - only required when NotifyUser is enabled

    Privacy / audit:
    - This runbook reads sensitive identity data (registered MFA methods, including phone numbers).
      Phone numbers are masked by default. Set MaskPhoneNumbers to false only when full numbers are
      required for legitimate support purposes; the action is logged with CallerName.
    - When NotifyUser is enabled, the target user is notified by email that an administrator has
      retrieved their MFA methods. This requires the tenant setting RJReport.EmailSender to be
      configured.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "NotifyUser": {
                "DisplayName": "Notify user via email",
                "Hide": true
            },
            "MaskPhoneNumbers": {
                "DisplayName": "Mask phone numbers (show last 4 digits only)",
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
            "LanguageOverride": {
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

param (
    [Parameter(Mandatory = $true)]
    [String]$UserName,

    [bool]$NotifyUser = $false,

    [bool]$MaskPhoneNumbers = $false,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_DisplayName" } )]
    [string]$ServiceDeskDisplayName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_EMail" } )]
    [string]$ServiceDeskEmail,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_Phone" } )]
    [string]$ServiceDeskPhone,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_PortalUrl" } )]
    [string]$ServiceDeskPortalUrl,

    [string]$ServiceDeskTicketUrl = "",

    # LanguageOverride allows forcing a specific notification email language ('DE' or 'EN'); empty = auto-detect from usage location
    [ValidateSet('', 'DE', 'EN')]
    [string]$LanguageOverride = "",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

$Version = "1.1.0"
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "NotifyUser: $NotifyUser" -Verbose
Write-RjRbLog -Message "MaskPhoneNumbers: $MaskPhoneNumbers" -Verbose
Write-RjRbLog -Message "ServiceDeskDisplayName: $ServiceDeskDisplayName" -Verbose
Write-RjRbLog -Message "ServiceDeskEmail: $ServiceDeskEmail" -Verbose
Write-RjRbLog -Message "ServiceDeskPhone: $ServiceDeskPhone" -Verbose
Write-RjRbLog -Message "ServiceDeskPortalUrl: $ServiceDeskPortalUrl" -Verbose
Write-RjRbLog -Message "ServiceDeskTicketUrl: $ServiceDeskTicketUrl" -Verbose
Write-RjRbLog -Message "LanguageOverride: $LanguageOverride" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Verify the Automation Account managed identity has the required Graph application permissions (UserAuthenticationMethod.Read.All, User.Read.All). Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Microsoft Graph connection failed."
}

if ($NotifyUser) {
    try {
        Connect-RjRbGraph | Out-Null
    }
    catch {
        Write-Error "Failed to initialize the RealmJoin Graph context required for sending the notification email via Send-RjReportEmail. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "RealmJoin Graph connection failed."
    }
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    $StatusQuo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$UserName`?`$select=id,userPrincipalName,displayName,mail,accountEnabled,usageLocation" -Method GET -ErrorAction Stop
}
catch {
    Write-Error "User '$UserName' could not be resolved in Microsoft Entra ID. Verify the User Principal Name is correct and the managed identity has the 'User.Read.All' application permission. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "User lookup failed."
}

$CurrentDisplayName = $StatusQuo.displayName
$CurrentUpn = $StatusQuo.userPrincipalName
$CurrentObjectId = $StatusQuo.id
$CurrentMail = $StatusQuo.mail
$CurrentAccountEnabled = $StatusQuo.accountEnabled
$CurrentUsageLocation = $StatusQuo.usageLocation

Write-Output "User:           $CurrentDisplayName <$CurrentUpn>"
Write-Output "Object ID:      $CurrentObjectId"
Write-Output "Account state:  $(if ($CurrentAccountEnabled) { 'Enabled' } else { 'Disabled' })"
Write-Output "Primary email:  $(if ([string]::IsNullOrWhiteSpace($CurrentMail)) { '(none)' } else { $CurrentMail })"

if ($NotifyUser) {
    if ([string]::IsNullOrWhiteSpace($CurrentMail)) {
        Write-RjRbLog -Message "WARNING: NotifyUser is enabled but the target user has no primary email address. The notification email will be skipped."
    }
    if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
        Write-Error "NotifyUser is enabled but the 'RJReport.EmailSender' tenant setting is empty. Configure a valid sender email address in RealmJoin settings or disable NotifyUser." -ErrorAction Continue
        throw "Sender email address not configured."
    }
}

#endregion

########################################################
#region     Email Branding Function
########################################################

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
#region     Main Part
########################################################

function Format-PhoneNumberDisplay {
    param(
        [string]$PhoneNumber,
        [bool]$Mask
    )
    if ([string]::IsNullOrWhiteSpace($PhoneNumber)) { return "" }
    if (-not $Mask) { return $PhoneNumber }
    $cleaned = $PhoneNumber -replace '\s', ''
    if ($cleaned.Length -le 4) { return $PhoneNumber }
    $visible = $cleaned.Substring($cleaned.Length - 4)
    $maskedPart = '*' * ($cleaned.Length - 4)
    return "$maskedPart$visible"
}

function Get-AuthMethodFriendlyName {
    param([string]$OdataType)
    switch ($OdataType) {
        '#microsoft.graph.fido2AuthenticationMethod' { 'FIDO2 Security Key'; break }
        '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' { 'Microsoft Authenticator'; break }
        '#microsoft.graph.phoneAuthenticationMethod' { 'Phone'; break }
        '#microsoft.graph.softwareOathAuthenticationMethod' { 'Third-party OATH (Software)'; break }
        '#microsoft.graph.temporaryAccessPassAuthenticationMethod' { 'Temporary Access Pass'; break }
        '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' { 'Windows Hello for Business'; break }
        '#microsoft.graph.emailAuthenticationMethod' { 'Email (SSPR)'; break }
        '#microsoft.graph.passwordAuthenticationMethod' { 'Password'; break }
        '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod' { 'Passwordless Microsoft Authenticator'; break }
        '#microsoft.graph.platformCredentialAuthenticationMethod' { 'Platform Credential (Passkey)'; break }
        default { ($OdataType -replace '#microsoft\.graph\.', '') -replace 'AuthenticationMethod$', '' }
    }
}

Write-Output ""
Write-Output "Authentication Methods"
Write-Output "---------------------"

try {
    $methodsResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$CurrentObjectId/authentication/methods" -Method GET -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve authentication methods for '$CurrentUpn'. The managed identity needs the 'UserAuthenticationMethod.Read.All' application permission. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Authentication method lookup failed."
}

$methods = @($methodsResponse.value)

if ($methods.Count -eq 0) {
    Write-Output "No authentication methods are registered for this user."
}
else {
    Write-Output "Found $($methods.Count) authentication method(s):"
    Write-Output ""

    $methodNumber = 0
    foreach ($method in $methods) {
        $methodNumber++
        $type = Get-AuthMethodFriendlyName -OdataType $method.'@odata.type'

        # Detect passkeys (software/platform-bound) reported as FIDO2 by known AAGUIDs or model names
        if ($method.'@odata.type' -eq '#microsoft.graph.fido2AuthenticationMethod') {
            $passkeyProviders = @{
                '90a3ccdf-635c-4729-a248-9b709135078f' = 'Microsoft Authenticator (iOS)'
                'de1e552d-db1d-4423-a619-566b625cdc84' = 'Microsoft Authenticator (Android)'
                'dd4ec289-e01d-41c9-bb89-70fa845d4bf2' = 'iCloud Keychain'
                'fbfc3007-154e-4ecc-8c0b-6e020557d7bd' = 'iCloud Keychain'
                'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4' = 'Google Password Manager'
                'adce0002-35bc-c60a-648b-0b25f1f05503' = 'Google Chrome'
                'b5397571-f314-4571-b765-151b3d2d5983' = 'Windows Hello'
                '08987058-cadc-4b81-b6e1-30de50dcbe96' = 'Windows Hello'
                '9ddd1817-af5a-4672-a2b9-3e3dd95000a9' = 'Windows Hello'
                '6028b017-b1d4-4c02-b4b3-afcdafc96bb2' = 'Windows Hello'
                '53414d53-554e-4700-0000-000000000000' = 'Samsung Pass'
                '17290f1e-c212-34d0-1423-365d729f09d9' = '1Password'
                'bada5566-a7aa-401f-bd96-45619a55120d' = '1Password'
                'd548826e-79b4-db40-a3d8-11116f7e8349' = 'Bitwarden'
            }
            $matchedProvider = $passkeyProviders[$method.aaGuid]
            if ($matchedProvider) {
                $type = "Passkey ($matchedProvider)"
            }
            elseif ($method.model -match 'Microsoft Authenticator|iCloud|Google|Chrome|Samsung|1Password|Bitwarden|Dashlane|Keeper') {
                $type = "Passkey ($($method.model))"
            }
        }

        Write-Output "[$methodNumber] $type"

        if ($method.id) {
            Write-Output "    Method ID:     $($method.id)"
        }

        switch ($method.'@odata.type') {
            '#microsoft.graph.phoneAuthenticationMethod' {
                $phoneType = if ($method.phoneType) { $method.phoneType } else { 'unknown' }
                $displayedPhone = Format-PhoneNumberDisplay -PhoneNumber $method.phoneNumber -Mask $MaskPhoneNumbers
                Write-Output "    Phone type:    $phoneType"
                Write-Output "    Phone number:  $displayedPhone"
                if ($method.smsSignInState) {
                    Write-Output "    SMS sign-in:   $($method.smsSignInState)"
                }
            }
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                if ($method.displayName)     { Write-Output "    Device:        $($method.displayName)" }
                if ($method.deviceTag)       { Write-Output "    Device tag:    $($method.deviceTag)" }
                if ($method.phoneAppVersion) { Write-Output "    App version:   $($method.phoneAppVersion)" }
            }
            '#microsoft.graph.fido2AuthenticationMethod' {
                if ($method.displayName)      { Write-Output "    Display name:  $($method.displayName)" }
                if ($method.model)            { Write-Output "    Model:         $($method.model)" }
                if ($method.aaGuid)           { Write-Output "    AA GUID:       $($method.aaGuid)" }
                if ($method.attestationLevel) { Write-Output "    Attestation:   $($method.attestationLevel)" }
            }
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' {
                if ($method.displayName) { Write-Output "    Display name:  $($method.displayName)" }
                if ($method.deviceId)    { Write-Output "    Device ID:     $($method.deviceId)" }
                if ($method.keyStrength) { Write-Output "    Key strength:  $($method.keyStrength)" }
            }
            '#microsoft.graph.emailAuthenticationMethod' {
                $email = $method.emailAddress
                if ($MaskPhoneNumbers -and -not [string]::IsNullOrWhiteSpace($email)) {
                    $atIndex = $email.IndexOf('@')
                    if ($atIndex -gt 1) {
                        $email = $email.Substring(0, 1) + ('*' * ($atIndex - 1)) + $email.Substring($atIndex)
                    }
                }
                Write-Output "    Email:         $email"
            }
            '#microsoft.graph.softwareOathAuthenticationMethod' {
                Write-Output "    Secret key:    (configured)"
            }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                if ($method.lifetimeInMinutes)       { Write-Output "    Lifetime:      $($method.lifetimeInMinutes) min" }
                if ($method.startDateTime)           { Write-Output "    Start time:    $($method.startDateTime)" }
                if ($null -ne $method.isUsable)      { Write-Output "    Usable:        $($method.isUsable)" }
                if ($null -ne $method.isUsableOnce)  { Write-Output "    One-time:      $($method.isUsableOnce)" }
            }
            '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod' {
                if ($method.displayName) { Write-Output "    Device:        $($method.displayName)" }
            }
            '#microsoft.graph.platformCredentialAuthenticationMethod' {
                if ($method.displayName) { Write-Output "    Display name:  $($method.displayName)" }
                if ($method.platform)    { Write-Output "    Platform:      $($method.platform)" }
            }
        }

        if ($method.createdDateTime) {
            Write-Output "    Registered:    $($method.createdDateTime)"
        }
        Write-Output ""
    }
}

Write-Output ""
Write-Output "Notify User"
Write-Output "---------------------"

$brandingMailParams = @{}
if (-not $NotifyUser) {
    Write-Output "NotifyUser is disabled - no notification email sent."
}
elseif ([string]::IsNullOrWhiteSpace($CurrentMail)) {
    Write-Output "Skipped: target user has no primary email address."
}
else {
    $tenantDisplayName = "your organization"
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($tenantInfo -and $tenantInfo.value -and $tenantInfo.value.Count -gt 0 -and $tenantInfo.value[0].displayName) {
            $tenantDisplayName = $tenantInfo.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not retrieve tenant display name. Falling back to a generic value. Error: $($_.Exception.Message)"
    }

    # Determine effective language: explicit override takes precedence, otherwise fall back to usage location
    $useGerman = if (-not [string]::IsNullOrWhiteSpace($LanguageOverride)) { $LanguageOverride -eq 'DE' } else { $CurrentUsageLocation -eq 'DE' }

    # Build Service Desk contact information section
    $serviceDeskSection = ""
    if ($ServiceDeskDisplayName -or $ServiceDeskEmail -or $ServiceDeskPhone -or $ServiceDeskPortalUrl -or $ServiceDeskTicketUrl) {
        if ($useGerman) {
            $serviceDeskSection = "`n`n### Service Desk Kontaktinformationen`n"
        }
        else {
            $serviceDeskSection = "`n`n### Service Desk Contact Information`n"
        }
        if ($ServiceDeskDisplayName) {
            $serviceDeskSection += "`n $($ServiceDeskDisplayName)"
        }
        if ($ServiceDeskEmail) {
            $serviceDeskSection += "`n **Email:** [$($ServiceDeskEmail)](mailto:$($ServiceDeskEmail))"
        }
        if ($ServiceDeskPhone) {
            if ($useGerman) {
                $serviceDeskSection += "`n **Telefon:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
            }
            else {
                $serviceDeskSection += "`n **Phone:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
            }
        }
        if ($ServiceDeskPortalUrl) {
            $serviceDeskSection += "`n **Portal:** [$($ServiceDeskPortalUrl)]($($ServiceDeskPortalUrl))"
        }
        if ($ServiceDeskTicketUrl) {
            $serviceDeskSection += "`n **Ticket:** [$($ServiceDeskTicketUrl)]($($ServiceDeskTicketUrl))"
        }
    }

    if ($useGerman) {
        $subject = "Ihre MFA-Methoden wurden von einem Administrator abgerufen"
        $markdownContent = @"
Hallo $CurrentDisplayName,

Dies ist eine automatische Benachrichtigung von $tenantDisplayName.

Ein Administrator hat eine Liste Ihrer registrierten Multi-Faktor-Authentifizierungsmethoden (MFA) über das RealmJoin-Portal abgerufen. Es wurden keine Änderungen an Ihrem Konto oder Ihren Authentifizierungsmethoden vorgenommen.

Falls Sie diesen Vorgang nicht erwartet haben, wenden Sie sich bitte an Ihre IT-Administration.$serviceDeskSection

Durchgeführt von: $CallerName
Datum (UTC):      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Mit freundlichen Grüßen,
IT-Administration

---

*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*
"@
    }
    else {
        $subject = "Your MFA methods were retrieved by an administrator"
        $markdownContent = @"
Hello $CurrentDisplayName,

This is an automated notification from $tenantDisplayName.

An administrator has retrieved a list of your registered multi-factor authentication (MFA) methods through the RealmJoin portal. No changes were made to your account or to any of your authentication methods.

If you did not expect this lookup, please contact your IT administrator.$serviceDeskSection

Action performed by: $CallerName
Date (UTC):          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Regards,
IT Administration

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $CurrentMail -Subject $subject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams
        Write-Output "Notification email sent to $CurrentMail."
    }
    catch {
        Write-Error "Failed to send notification email to '$CurrentMail'. Verify the managed identity has the 'Mail.Send' application permission and that the sender '$EmailFrom' is a valid mailbox in this tenant. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Notification email send failed."
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

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
