# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/54

<#
  .SYNOPSIS
  Check for last Azure AD Connect Sync Cycle.

  .DESCRIPTION
  This runbook checks the Azure AD Connect sync status and the last sync date and time.

  .NOTES
  Permissions:
  MS Graph (API)
  - Directory.Read.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [string] $sendAlertTo = "ugur.koc@glueckkanja.com",
    [string] $sendAlertFrom = "runbooks@contoso.com"
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Retrieve organization information
$organization = Invoke-RjRbRestMethodGraph -Resource "/organization" -ErrorAction SilentlyContinue

$HTMLBody = "<h2>Azure AD Connect Sync Status</h2>"

if ($organization.value) {
    foreach ($org in $organization.value) {
        $syncEnabled = $org.onPremisesSyncEnabled
        $lastSyncDate = $org.onPremisesLastSyncDateTime
        
        if ($syncEnabled -eq $true) {
            $HTMLBody += "<p>Azure AD Connect sync is enabled.</p>"
            $HTMLBody += "<p>Last sync date and time: $lastSyncDate</p>"
        } else {
            $HTMLBody += "<p>Azure AD Connect sync is not enabled.</p>"
        }
    }
} else {
    "No organization data found."
}

if ($HTMLBody) {
    $message = @{
        subject = "[Automated Report] Azure AD Connect Sync Status"
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

    $jsonBody = @{ message = $message } | ConvertTo-Json -Depth 4

    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body $jsonBody -ContentType "application/json" | Out-Null
    "## Report sent to '$sendAlertTo'."
} else {
    "No organization data found."
}
