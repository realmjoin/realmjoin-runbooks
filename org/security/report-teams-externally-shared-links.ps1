<#
  .SYNOPSIS
  Scan all Teams for externally shared links. Report those to team owners.

  .DESCRIPTION
  Scan all Teams for externally shared links. Report those to team owners.

  .PARAMETER fromUser
  Email-Address of a shared mailbox to be the sender of the reports.

  .PARAMETER failsafeRecipient
  Email-Address to send the report to if no owners exist.

  .PARAMETER ccToFailsafeRecipient
  CC the report to failsafeRecipient additionally to the owners.

  .PARAMETER overrideRecipient
  Ignore owners and failsafeRecipient and send the report exclusively to this recipient.
  Primarilly intended for testing.


  .NOTES
  Permissions
   MS Graph (API): 
   - Policy.Read.All
   - User.SendMail
   

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "overrideRecipient": {
                "Hide": true
            },
            "perGroupRunbookName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules RealmJoin.RunbookHelper

param(
    [string]$fromUser = "RoboReports@contoso.com",
    [string]$failsafeRecipient = "ciso@contoso.com",
    [bool]$ccToFailsafeRecipient = $false,
    [string]$overrideRecipient = "",
    [string]$perGroupRunbookName = "rjgit-group_security_report-teams-externally-shared-links"
)

Connect-RjRbGraph

$allGroups = Invoke-RjRbRestMethodGraph -Resource "/groups/" -FollowPaging

$teamsGroups = $allGroups | Where-Object { $_.resourceProvisioningOptions -contains "Team" }
" $($teamsGroups.count) Team Sites found."

foreach ($team in $teamsGroups) {
    "# Starting report for '$($team.displayName)'"
    Start-AutomationRunbook -Name $perGroupRunbookName -Parameters @{ groupId = $team.id ;fromUser = $fromUser; failsafeRecipient = $failsafeRecipient; ccToFailsafeRecipient = $ccToFailsafeRecipient; overrideRecipient = $overrideRecipient }
    Start-Sleep -Seconds 30
}

