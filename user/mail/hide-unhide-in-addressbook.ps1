<#
  .SYNOPSIS
  (Un)Hide this mailbox in address book.

  .DESCRIPTION
  (Un)Hide this mailbox in address book.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [Parameter(Mandatory = $true)] [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Hide the mailbox" } )]
    [bool] $hide = $true
)

try {
    Connect-RjRbExchangeOnline

    if ($hide) {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $true 
        "Mailbox $UserName is hidden."
    }
    else {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $false
        "Mailbox $UserName is not hidden."    
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}