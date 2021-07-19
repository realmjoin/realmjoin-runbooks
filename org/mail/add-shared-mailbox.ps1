<#
  .SYNOPSIS
  Create a shared mailbox.

  .DESCRIPTION
  Create a shared mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $MailboxName,
    [ValidateScript( { Use-RJInterface -DisplayName "DisplayName" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" } )]
    [string] $DelegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false
)

try {
    Connect-RjRbExchangeOnline

    # make sure a displayName exists
    if (-not $DisplayName) {
        $DisplayName = $MailboxName
    }

    # Create the mailbox
    $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $MailboxName 

    if ($DelegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
    }

    "Shared Mailbox $MailboxName has been created."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}