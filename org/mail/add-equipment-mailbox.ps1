<#
  .SYNOPSIS
  Create an equipment mailbox.

  .DESCRIPTION
  Create an equipment mailbox.

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
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" } )]
    [string] $DelegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically accept meeting requests" } )]
    [bool] $AutoAccept = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false
)

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name      = $MailboxName
        Alias     = $MailboxName
        Equipment = $true
    }

    if ($DisplayName) {
        $invokeParams += @{ DisplayName = $DisplayName }
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    if ($DelegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $MailboxName -ResourceDelegates $DelegateTo 
    }

    if ($AutoAccept) {
        Set-CalendarProcessing -Identity $MailboxName -AutomateProcessing "AutoAccept"
    }

    "## Equipment Mailbox $MailboxName has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}