<#
  .SYNOPSIS
  List permissions on a (shared) mailbox.

  .DESCRIPTION
  List permissions on a (shared) mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User  -DisplayName "User/Mailbox" } )]
    [Parameter(Mandatory = $true)] 
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

"## Trying to list all mailbox access / send permissions granted on mailbox '$UserName'."

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User  object '$UserName' has no mailbox."
    }

    "## Dump Mailbox Permission Details for '$UserName'"
    ""
    "## Mailbox Access Permissions"
    Get-MailboxPermission -Identity $UserName | Where-Object { ($_.user -like '*@*') } | Format-Table -Property Identity, User, AccessRights -AutoSize | Out-String
    ""
    "## Recipient/Sender (SendAs) Permissions"
    Get-RecipientPermission -Identity $UserName | Where-Object { ($_.Trustee -like '*@*') } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String
    ""
    "## SendOnBehalf Permissions"
    (Get-Mailbox -Identity $UserName).GrantSendOnBehalfTo | ForEach-Object {
        $sobTrustee = Get-EXOMailbox -Identity $_
        $result = @{}
        $result.Identity = $user.Identity
        $result.Trustee = $sobTrustee.UserPrincipalName
        $result.AccessRights = "{SendOnBehalf}"
        [PsCustomObject]$result
    } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}