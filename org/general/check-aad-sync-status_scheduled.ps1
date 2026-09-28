<#
	.SYNOPSIS
	Check the last Entra Connect sync and alert when it is off

	.DESCRIPTION
	Checks whether directory synchronization from on-premises Active Directory is enabled in the tenant. If it is not, an alert email is sent.

	.PARAMETER sendAlertTo
	Gets the alert email when directory synchronization is found disabled.

	.PARAMETER sendAlertFrom
	User in the tenant the alert is sent as; needs a mailbox.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"sendAlertTo": {
				"DisplayName": "Alert recipient"
			},
			"sendAlertFrom": {
				"DisplayName": "Alert sender"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
param(
    [string] $sendAlertTo = "support@glueckkanja.com",
    [string] $sendAlertFrom = "runbooks@glueckkanja.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
