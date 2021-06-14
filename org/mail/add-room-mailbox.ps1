#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] [string] $mailboxName,
    [string] $displayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [string] $delegateTo,
    [int] $capacity,
    [bool] $autoAccept = $false,
    [bool] $autoMapping = $false
)

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name  = $mailboxName
        Alias = $mailboxName
        Room  = $true
    }

    if ($displayName) {
        $invokeParams += @{ DisplayName = $displayName }
    }

    if ($capacity -and ($capacity -gt 0)) {
        $invokeParams += @{ ResourceCapacity = $capacity }
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    if ($delegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $delegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $autoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $mailboxName -ResourceDelegates $delegateTo 
    }

    if ($autoAccept) {
        Set-CalendarProcessing -Identity $mailboxName -AutomateProcessing "AutoAccept"
    }

    "Room Mailbox $mailboxName has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}