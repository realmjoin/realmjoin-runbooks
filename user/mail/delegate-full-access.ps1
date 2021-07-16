<#
  .SYNOPSIS
  Grant another user full access to this mailbox.

  .DESCRIPTION
  Grant another user full access to this mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox"} )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false
)


try {
    "## Trying to connect and check for $UserName"
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User $userName has no mailbox."
    }

    "## Current Permission Delegations"
    Get-MailboxPermission -Identity $UserName | select -expandproperty User

    ""
    if ($Remove) {
        # Remove access
        Remove-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -confirm:$false | Out-Null
        "## FullAccess Permission for $delegateTo removed from mailbox $UserName"
    }
    else {
        # Add access
        Add-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        "## FullAccess Permission for $delegateTo added to mailbox  $UserName"
    }

    ""
    "## Dump Mailbox Details"
    Get-MailboxPermission -Identity $UserName
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}