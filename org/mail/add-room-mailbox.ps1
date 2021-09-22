<#
  .SYNOPSIS
  Create a room resource.

  .DESCRIPTION
  Create a room resource.

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
    [ValidateScript( { Use-RJInterface -DisplayName "Room capacity (people)" } )]
    [int] $Capacity,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically accept meeting requests" } )]
    [bool] $AutoAccept = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false
)

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name  = $MailboxName
        Alias = $MailboxName
        Room  = $true
    }

    if ($DisplayName) {
        $invokeParams += @{ DisplayName = $DisplayName }
    }

    if ($Capacity -and ($Capacity -gt 0)) {
        $invokeParams += @{ ResourceCapacity = $Capacity }
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    if ($DelegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $MailboxName -ResourceDelegates $DelegateTo -AutomateProcessing AutoAccept -AllRequestInPolicy $true -AllBookInPolicy $false
    }

    if ($AutoAccept) {
        Set-CalendarProcessing -Identity $MailboxName -AutomateProcessing "AutoAccept" -AllRequestInPolicy $true -AllBookInPolicy $true
    }

    "## Room Mailbox '$MailboxName' has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}