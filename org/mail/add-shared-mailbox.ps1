#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] [string] $mailboxName,
    [string] $displayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [string] $delegateTo,
    [bool] $AutoMapping = $false
)

Connect-RjRbExchangeOnline

# make sure a displayName exists
if (-not $displayName) {
    $displayName = $mailboxName
}

# Create the mailbox
$mailbox = New-Mailbox -Shared -Name $mailboxName -DisplayName $displayName -Alias $mailboxName 

if ($delegateTo) {
    # "Grant SendOnBehalf"
    $mailbox | Set-Mailbox -GrantSendOnBehalfTo $delegateTo | Out-Null
    # "Grant FullAccess"
    $mailbox | Add-MailboxPermission -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
}

"Shared Mailbox $mailboxName has been created."

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null