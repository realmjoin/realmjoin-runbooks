#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] [string] $mailboxName,
    [string] $displayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [string] $delegateTo,
    [bool] $autoAccept = $false,
    [bool] $autoMapping = $false
)

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name      = $mailboxName
        Alias     = $mailboxName
        Equipment = $true
    }

    if ($displayName) {
        $invokeParams += @{ DisplayName = $displayName }
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    if ($delegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $delegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $mailboxName -ResourceDelegates $delegateTo 
    }

    if ($autoAccept) {
        Set-CalendarProcessing -Identity $mailboxName -AutomateProcessing "AutoAccept"
    }

    "Equipment Mailbox $mailboxName has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}