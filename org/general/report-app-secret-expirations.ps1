# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/88

<#
  .SYNOPSIS
  Monitor/Report expiry of Azure AD application credentials.

  .DESCRIPTION
  Monitor/Report expiry of Azure AD application credentials.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Application.Read.All,
  - Mail.Send

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    [int] $Days = 30, # Können wir das hier als Dropdown-Wert anbieten?
    [string] $sendAlertTo = "ulimuli92@googlemail.com",
    # Please make sure this from-Adress exists in Exchange Online
    [string] $sendAlertFrom = "runbooks@contoso.com"
)

Connect-RjRbGraph

$minDate = (get-date) + (New-TimeSpan -Day $Days)
$HTMLBody = ""

$applications = Invoke-RjRbRestMethodGraph -Resource "/applications" -ErrorAction SilentlyContinue

if ($applications.value) {
    foreach ($application in $applications.value) {
        $passwordCredentials = Invoke-RjRbRestMethodGraph -Resource "/applications/$($application.id)/passwordCredentials" -ErrorAction SilentlyContinue
        
        if ($passwordCredentials.value) {
            foreach ($secret in $passwordCredentials.value) {
                $expiryDate = (get-date -date $secret.endDateTime)
                $daysUntilExpiry = ($expiryDate - (get-date)).Days

                "Application Name: $($application.displayName)"
                "Application ID: $($application.id)"
                "  Key ID: $($secret.keyId)"
                "  Expiry Date: $($expiryDate.ToString('yyyy-MM-dd'))"
                "  Days Until Expiry: $daysUntilExpiry"

                if ($expiryDate -le $minDate) {
                    "## ALERT - Days left is below limit!"
                    $HTMLBody += "<p><b>Application '$($application.displayName)' credential with Key ID '$($secret.keyId)' is about to expire: $daysUntilExpiry days left.</b></p>"
                }
            }
        }
    }
}

if ($HTMLBody) {
    "## Alerts found"
    $message = @{
        subject = "[Automated eMail] ALERT - Azure AD application credential warnings."
        body    = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = $sendAlertTo
                }
            }
        )
    }

    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body (@{ message = $message } | ConvertTo-Json -Depth 4) -ContentType "application/json" | Out-Null
    "## Alert sent to '$sendAlertTo'."
}
