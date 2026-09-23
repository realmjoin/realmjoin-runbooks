<#
    .SYNOPSIS
    Report the PIM role activations of the last month by email

    .DESCRIPTION
    Reads the Entra ID audit log for Privileged Identity Management role activations of the last month and sends them as an email report, so privileged access can be reviewed regularly. Nothing is changed.

    .PARAMETER sendAlertTo
    Gets the monthly PIM activation report.

    .PARAMETER sendAlertFrom
    User in the tenant the report is sent as; needs a mailbox.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "sendAlertTo": {
                "DisplayName": "Report recipient"
            },
            "sendAlertFrom": {
                "DisplayName": "Report sender"
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
    [string] $sendAlertFrom = "runbook@glueckkanja.com",
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

# Retrieve PIM activation audit logs for the last month
$startDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$endDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
"Retrieving PIM activation logs from $startDate to $endDate..."

$filter = "activityDisplayName eq 'Add member to role completed (PIM activation)' and activityDateTime ge $startDate and activityDateTime le $endDate"
$pimActivations = Invoke-RjRbRestMethodGraph -Resource "/auditLogs/directoryAudits" -OdFilter $filter -Beta -ErrorAction SilentlyContinue

$HTMLBody = "<h2>PIM Activations Report</h2>"
$HTMLBody += "<table border='1'><tr><th>Date</th><th>Requestor</th><th>UPN</th><th>Role</th><th>Primary Target</th><th>PIM Group</th><th>Reason</th><th>Status</th></tr>"

if ($pimActivations) {
    "PIM activations found. Processing logs..."
    foreach ($activation in $pimActivations) {
        $logEntry = [PSCustomObject]@{
            Date          = $activation.activityDateTime
            Requestor     = $activation.targetResources[2].displayName
            UPN           = $activation.initiatedBy.user.userPrincipalName
            Role          = $activation.targetResources[0].displayName
            PrimaryTarget = $activation.targetResources[3].displayName
            PIMGroup      = $activation.targetResources[6].displayName
            Reason        = $activation.resultReason
            Status        = $activation.result
        }

        $HTMLBody += "<tr>"
        $HTMLBody += "<td>$($logEntry.Date)</td>"
        $HTMLBody += "<td>$($logEntry.Requestor)</td>"
        $HTMLBody += "<td>$($logEntry.UPN)</td>"
        $HTMLBody += "<td>$($logEntry.Role)</td>"
        $HTMLBody += "<td>$($logEntry.PrimaryTarget)</td>"
        $HTMLBody += "<td>$($logEntry.PIMGroup)</td>"
        $HTMLBody += "<td>$($logEntry.Reason)</td>"
        $HTMLBody += "<td>$($logEntry.Status)</td>"
        $HTMLBody += "</tr>"
    }
    "Logs processed."
}
else {
    "No PIM activations found."
}

$HTMLBody += "</table>"

if ($pimActivations) {
    $message = @{
        subject      = "[Automated Report] PIM Activations Report"
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
    "No report sent as no PIM activations were found."
}
