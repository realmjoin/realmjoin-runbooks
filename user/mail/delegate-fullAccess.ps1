#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

param
(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $delegateTo,
    [bool] $AutoMapping = $false,
    [bool] $Remove = $false
)

$VerbosePreference = "SilentlyContinue"

Connect-RjRbExchangeOnline

# Check if User has a mailbox
# No need to check trustee for a mailbox with "FullAccess"
$user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
if (-not $user) {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    throw "User $userName has no mailbox."
}

if ($Remove)
{
    # Remove access
    Remove-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -confirm:$false | Out-Null
    "FullAccess Permission for $delegateTo removed from mailbox $UserName"
} else {
    # Add access
    Add-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
    "FullAccess Permission for $delegateTo added to mailbox  $UserName"
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null