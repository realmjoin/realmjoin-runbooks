<#
    .SYNOPSIS
    Remove all App- and Mobilephone auth methods for a user

    .DESCRIPTION
    Removes authenticator app and phone-based authentication methods for a user. This forces the user to re-enroll MFA methods after the reset. Optionally a notification email can be sent to the user informing them that their MFA methods have been reset through this runbook.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER NotifyUser
    When enabled, sends a notification email to the target user informing them that their MFA methods were reset by an administrator. Default is disabled.

    .PARAMETER EmailFrom
    Sender email address for the optional notification mail. Sourced from the RealmJoin tenant setting RJReport.EmailSender.

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
    Caller name is tracked purely for auditing purposes.

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
            "EmailFrom": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,

    [bool]$NotifyUser = $false,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,

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
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "NotifyUser: $NotifyUser" -Verbose
Write-RjRbLog -Message "LanguageOverride: $LanguageOverride" -Verbose

Connect-RjRbGraph

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    $statusQuo = Invoke-RjRbRestMethodGraph -Resource "/users/$($UserName)" -ErrorAction Stop
}
catch {
    Write-Error "User '$UserName' could not be resolved. Verify the User Principal Name is correct. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "User lookup failed."
}

$CurrentDisplayName = $statusQuo.displayName
$CurrentUpn = $statusQuo.userPrincipalName
$CurrentMail = $statusQuo.mail
$CurrentUsageLocation = $statusQuo.usageLocation

Write-Output "User:          $CurrentDisplayName <$CurrentUpn>"
Write-Output "Primary email: $(if ([string]::IsNullOrWhiteSpace($CurrentMail)) { '(none)' } else { $CurrentMail })"

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
#region     Main Part
########################################################

"## Trying to remove all MFA methods for user '$UserName'"

# "Find phone auth. methods for user $UserName"
$phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta

# "Find Authenticator App auth methods for user $UserName"
$appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta

# "Find Classic OATH App auth methods for user $UserName"
$OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods" -Beta

# "Find FIDO2 auth methods for user $UserName"
$fido2AMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods" -Beta

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs) -or ($OATHAMs) -or ($fido2AMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        "## Trying to remove mobile phone method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
            "## Reauth..."
            Connect-RjRbGraph -force
        }
    }

    $OATHAMs | ForEach-Object {
        "## Trying to remove OATH method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
            "## Reauth..."
            Connect-RjRbGraph -force
        }
    }

    $fido2AMs | ForEach-Object {
        "## Trying to remove FIDO2 method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
            "## Reauth..."
            Connect-RjRbGraph -force
        }
    }

    $appAMs | ForEach-Object {
        "## Trying to remove app method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
            "## Reauth..."
            Connect-RjRbGraph -force
        }
    }

    "## Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    # "Find phone auth. methods for user $UserName"
    $phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta

    # "Find Authenticator App auth methods for user $UserName"
    $appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta

    # "Find Classic OATH App auth methods for user $UserName"
    $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods" -Beta

    # "Find FIDO2 auth methods for user $UserName"
    $fido2AMs = $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods" -Beta

}

if ($count -le 3) {
    "## All App, OATH, FIDO2 and Mobile Phone MFA methods for '$UserName' successfully removed."
}
else {
    "## Could not remove all MFA methods for '$UserName'. Please review."
}

#endregion

########################################################
#region     Notify User
########################################################

Write-Output ""
Write-Output "Notify User"
Write-Output "---------------------"

if (-not $NotifyUser) {
    Write-Output "NotifyUser is disabled - no notification email sent."
}
elseif ([string]::IsNullOrWhiteSpace($CurrentMail)) {
    Write-Output "Skipped: target user has no primary email address."
}
else {
    $tenantDisplayName = "your organization"
    try {
        $tenantInfo = Invoke-RjRbRestMethodGraph -Resource "/organization" -ErrorAction Stop
        $tenantObj = @($tenantInfo)[0]
        if ($tenantObj -and $tenantObj.displayName) {
            $tenantDisplayName = $tenantObj.displayName
        }
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not retrieve tenant display name. Falling back to a generic value. Error: $($_.Exception.Message)"
    }

    $useGerman = if (-not [string]::IsNullOrWhiteSpace($LanguageOverride)) { $LanguageOverride -eq 'DE' } else { $CurrentUsageLocation -eq 'DE' }

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
        $subject = "Ihre MFA-Methoden wurden von einem Administrator zurückgesetzt"
        $markdownContent = @"
Hallo $CurrentDisplayName,

Dies ist eine automatische Benachrichtigung von $tenantDisplayName.

Ein Administrator hat alle Ihre registrierten Multi-Faktor-Authentifizierungsmethoden (MFA) über das RealmJoin-Portal zurückgesetzt. Sie werden bei der nächsten Anmeldung aufgefordert, Ihre MFA-Methoden neu zu registrieren.

Falls Sie diesen Vorgang nicht erwartet haben oder Fragen haben, wenden Sie sich bitte an Ihre IT-Administration.$serviceDeskSection

Durchgeführt von: $CallerName
Datum (UTC):      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Mit freundlichen Grüßen,
IT-Administration

---

*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*
"@
    }
    else {
        $subject = "Your MFA methods have been reset by an administrator"
        $markdownContent = @"
Hello $CurrentDisplayName,

This is an automated notification from $tenantDisplayName.

An administrator has reset all of your registered multi-factor authentication (MFA) methods through the RealmJoin portal. You will be prompted to re-enroll your MFA methods the next time you sign in.

If you did not expect this action or have any questions, please contact your IT administrator.$serviceDeskSection

Action performed by: $CallerName
Date (UTC):          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Regards,
IT Administration

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $CurrentMail -Subject $subject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-Output "Notification email sent to $CurrentMail."
    }
    catch {
        Write-Error "Failed to send notification email to '$CurrentMail'. Verify the managed identity has the 'Mail.Send' application permission and that the sender '$EmailFrom' is a valid mailbox in this tenant. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Notification email send failed."
    }
}

#endregion
