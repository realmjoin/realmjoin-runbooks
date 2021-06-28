<#
  .SYNOPSIS
  (Un)Hide this mailbox in address book.

  .DESCRIPTION
  (Un)Hide this mailbox in address book.
#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

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