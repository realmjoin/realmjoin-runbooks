<#
	.SYNOPSIS
	Check last Azure AD Connect sync status

	.DESCRIPTION
	This runbook checks whether on-premises directory synchronization is enabled and when the last sync happened.
	It can send an email alert if synchronization is not enabled.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.PARAMETER sendAlertTo
	Email address to send the report to.

	.PARAMETER sendAlertFrom
	Sender mailbox used for sending the report.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [string] $sendAlertTo = "support@glueckkanja.com",
    [string] $sendAlertFrom = "runbooks@glueckkanja.com"
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

"Connecting to RJ Runbook Graph..."
Connect-RjRbGraph
"Connection established."

# Retrieve organization information
"Retrieving organization information..."
$organization = Invoke-RjRbRestMethodGraph -Resource "/organization" -ErrorAction SilentlyContinue

$HTMLBody = "<h2>Azure AD Connect Sync Status</h2>"
$sendEmail = $false

if ($organization) {
    foreach ($org in $organization) {
        $syncEnabled = $org.onPremisesSyncEnabled
        $lastSyncDate = $org.onPremisesLastSyncDateTime

        if ($syncEnabled -eq $true) {
            $HTMLBody += "<p>Azure AD Connect sync is enabled.</p>"
            $HTMLBody += "<p>Last sync date and time: $lastSyncDate</p>"
        }
        else {
            $HTMLBody += "<p>Azure AD Connect sync is not enabled.</p>"
            $sendEmail = $true
        }
    }
}
else {
    "No organization data found."
}

if ($sendEmail) {
    $message = @{
        subject      = "[Automated Report] Azure AD Connect Sync Status"
        body         = @{
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

    "Sending report to '$sendAlertTo'..."
    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body @{ message = $message } -ContentType "application/json" | Out-Null
    "Report sent to '$sendAlertTo'."
}
else {
    "No report sent as sync is enabled or no organization data was found."
}
