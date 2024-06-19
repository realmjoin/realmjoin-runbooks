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
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [int] $Days = 30, # Number of days to check for upcoming expiry
    [string] $sendAlertTo = "ugur.koc@glueckkanja.com",
    [string] $sendAlertFrom = "administrator@sl6ll.onmicrosoft.com"
)

"Connecting to RJ Runbook Graph..."
Connect-RjRbGraph
"Connection established."

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$minDate = (Get-Date).AddDays($Days)
$HTMLBody = ""

"Retrieving Azure AD applications..."
$applications = Invoke-RjRbRestMethodGraph -Resource "/applications" -ErrorAction SilentlyContinue

if ($applications) {
    foreach ($application in $applications) {
        $passwordCredentials = Invoke-RjRbRestMethodGraph -Resource "/applications/$($application.id)/passwordCredentials" -ErrorAction SilentlyContinue
        
        if ($passwordCredentials) {
            foreach ($secret in $passwordCredentials) {
                $expiryDate = (Get-Date -Date $secret.endDateTime)
                $daysUntilExpiry = ($expiryDate - (Get-Date)).Days

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

    "Sending alert to '$sendAlertTo'..."
    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body @{ message = $message } -ContentType "application/json" | Out-Null
    "## Alert sent to '$sendAlertTo'."
} else {
    "## No alerts found."
}
