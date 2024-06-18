# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/74

<#
  .SYNOPSIS
  Scheduled Report on PIM Activations.

  .DESCRIPTION
  This runbook collects and reports PIM activation details, including date, requestor, UPN, role, primary target, PIM group, reason, and status, and sends it via email.

  .NOTES
  Permissions:
  MS Graph (API)
  - AuditLog.Read.All
  - Mail.Send

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [string] $sendAlertTo = "ugur.koc@glueckkanja.com",
    [string] $sendAlertFrom = "support@contoso.com"
)

 "Connecting to RJ Runbook Graph..."
Connect-RjRbGraph
 "Connection established."

# Retrieve PIM activation audit logs for the last month
$startDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$endDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
 "Retrieving PIM activation logs from $startDate to $endDate..."
$pimActivations = Invoke-RjRbRestMethodGraph -Resource "/auditLogs/directoryAudits?`$filter=activityDisplayName eq 'Add member to role completed (PIM activation)' and activityDateTime ge $startDate and activityDateTime le $endDate" -Beta -FollowPaging

"## PIM Activations:"
$pimActivations

$HTMLBody = "<h2>PIM Activations Report</h2>"
$HTMLBody += "<table border='1'><tr><th>Date</th><th>Requestor</th><th>UPN</th><th>Role</th><th>Primary Target</th><th>PIM Group</th><th>Reason</th><th>Status</th></tr>"

if ($pimActivations.value) {
     "PIM activations found. Processing logs..."
    foreach ($activation in $pimActivations.value) {
        $logEntry = [PSCustomObject]@{
            Date        = $activation.activityDateTime
            Requestor   = $activation.targetResources[2].displayName
            UPN         = $activation.initiatedBy.user.userPrincipalName
            Role        = $activation.targetResources[0].displayName
            PrimaryTarget = $activation.targetResources[3].displayName
            PIMGroup    = $activation.targetResources[6].displayName
            Reason      = $activation.resultReason
            Status      = $activation.result
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
} else {
     "No PIM activations found."
}

$HTMLBody += "</table>"

if ($pimActivations.value) {
    $message = @{
        subject = "[Automated Report] PIM Activations Report"
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

     "Sending report to '$sendAlertTo'..."
    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body $jsonBody -ContentType "application/json" | Out-Null
     "Report sent to '$sendAlertTo'."
} else {
     "No report sent as no PIM activations were found."
}
