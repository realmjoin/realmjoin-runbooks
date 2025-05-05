<#
  .SYNOPSIS
  Monitor/Report expiry of Apple device management certificates.

  .DESCRIPTION
  Monitor/Report expiry of Apple device management certificates.

  .NOTES
  Permissions:
  MS Graph (API)
  - DeviceManagementManagedDevices.Read.All,
  - DeviceManagementServiceConfig.Read.All,
  - DeviceManagementConfiguration.Read.All,
  - Mail.Send

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [int] $Days = 300,
    [string] $sendAlertTo = "support@glueckkanja.com",
    # Please make sure this from-Adress exists in Exchange Online
    [string] $sendAlertFrom = "runbook@glueckkanja.com"
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Retrieve tenant ID
$tenantDetails = Invoke-RjRbRestMethodGraph -Resource "/organization" -ErrorAction SilentlyContinue
$tenantId = $tenantDetails[0].id

$minDate = (get-date) + (New-TimeSpan -Day $Days)
$HTMLBody = "<p>Tenant ID: $tenantId</p>"

$applePushCerts = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/applePushNotificationCertificate" -ErrorAction SilentlyContinue
if ($applePushCerts) {
    #"## Apple Push Notification Certs found."
    foreach ($ApplePushCert in $applePushCerts) {
        "## Apple Push Cert '$($ApplePushCert.appleIdentifier)' expiry is/was on $((get-date -date $ApplePushCert.expirationDateTime).ToShortDateString())."
        "## -> $(((get-date -Date $ApplePushCert.expirationDateTime) - (get-date)).Days) days left."
        if (((get-date -Date $ApplePushCert.expirationDateTime) - $minDate) -le 0) {
            "## ALERT - Days left is below limit!"
            $HTMLBody += "<p><b>Apple Push Certificate '$($ApplePushCert.appleIdentifier)' about to expire: $(((get-date -Date $ApplePushCert.expirationDateTime) - (get-date)).Days) days left.</b></p>"
        }
        ""
    }
}

$vppTokens = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/vppTokens" -ErrorAction SilentlyContinue
if ($vppTokens) {
    #"## VPP Tokens found."
    foreach ($token in $vppTokens) {
        if ($token.state -ne 'valid') {
            "## VPP Token for '$($token.appleId)' is not valid."
            "## ALERT - VPP Token not valid!"
            $HTMLBody += "<p><b>Apple VPP Token '$($token.appleId)' is invalid!</b></p>"
        }
        else {
            "## VPP Token for '$($token.appleId)' expiry is/was on $((get-date -date $token.expirationDateTime).ToShortDateString())."
            "## -> $(((get-date -Date $token.expirationDateTime) - (get-date)).Days) days left."
            if (((get-date -date $token.expirationDateTime) - $minDate) -le 0 ) {
                "## ALERT - Days left is below limit!"
                $HTMLBody += "<p><b>Apple VPP Token '$($token.appleId)' about to expire: $(((get-date -Date $token.expirationDateTime) - (get-date)).Days) days left. </b></p>"
            }
        }
        ""
    }
}

$depSettings = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/depOnboardingSettings" -Beta -ErrorAction SilentlyContinue
if ($depSettings) {
    #"## DEP Settings found."
    foreach ($token in $depSettings) {
        "## DEP Settings for '$($token.appleIdentifier)' expiry is/was on $((get-date -date $token.tokenExpirationDateTime).ToShortDateString())."
        "## -> $(((get-date -Date $token.tokenExpirationDateTime) - (get-date)).Days) days left."
        if (((get-date -date $token.tokenExpirationDateTime) - $minDate) -le 0) {
            "## ALERT - Days left is below limit!"
            $HTMLBody += "<p><b>Apple DEP Settings for '$($token.appleIdentifier)' about to expire: $(((get-date -Date $token.tokenExpirationDateTime) - (get-date)).Days) days left.</b></p>"
        }
        ""
    }
}

if ($HTMLBody) {
    "## Alerts found"
    $message = @{
        subject = "[Automated eMail] ALERT - Apple Intune integration warnings."
        body    = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
    }

    $message.toRecipients = [array]@{
        emailAddress = @{
            address = $sendAlertTo
        }
    }

    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body @{ message = $message } | Out-Null
    "## Alert sent to '$sendAlertTo'."
}
