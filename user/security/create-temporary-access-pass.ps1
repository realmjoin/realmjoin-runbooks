<#
    .SYNOPSIS
    Create a Temporary Access Pass for this user

    .DESCRIPTION
    Creates a Temporary Access Pass (TAP) for this user, so they can sign in and set up their authentication methods without a password. Any existing pass is removed first and the new pass is shown in the runbook output. Optionally the user gets an email with the pass, in German for usage location DE and otherwise in English.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER LifetimeInMinutes
    How long the pass stays valid, between 60 and 480 minutes.

    .PARAMETER OneTimeUseOnly
    A one-time pass works for a single sign-in; otherwise it can be reused until it expires.

    .PARAMETER NotifyUser
    Whether the user is emailed the new pass. Preset in the runbook customization.

    .PARAMETER EmailFrom
    Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender.

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

    .PARAMETER ServiceDeskDisplayName
    Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName.

    .PARAMETER ServiceDeskEmail
    Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail.

    .PARAMETER ServiceDeskPhone
    Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone.

    .PARAMETER ServiceDeskPortalUrl
    Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl.

    .PARAMETER ServiceDeskTicketUrl
    Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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
            "BrandingAccentColor": {
                "Hide": true
            },
            "BrandingTextColor": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number -DisplayName "Lifetime (minutes)" } )]
    [ValidateRange(60, 480)]
    [int] $LifetimeInMinutes = 240,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "One-time use?" } )]
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string] $BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string] $BrandingTextColor,
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

$Version = "1.4.0"
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
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose

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
        Write-Warning "The sender email address is required when NotifyUser is enabled. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
        throw "EmailFrom is not configured in runbook customization."
    }
}

#endregion Parameter Validation

############################################################
#region     Email Branding Function
#
############################################################

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
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

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