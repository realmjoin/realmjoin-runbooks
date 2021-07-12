<#
  .SYNOPSIS
  Grant another user sendAs permissions on this mailbox.

  .DESCRIPTION
  Grant another user sendAs permissions on this mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

param
( 
    [Parameter(Mandatory = $true)]     
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false
)

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "SendAs"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "User $userName has no mailbox."
    }

    if ($Remove) {
        Remove-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
        "SendAs Permission for $delegateTo removed from mailbox $UserName"
    }
    else {
        Add-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
        "SendAs Permission for $delegateTo added to mailbox  $UserName"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}