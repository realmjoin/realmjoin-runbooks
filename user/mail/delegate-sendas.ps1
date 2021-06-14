#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

param
(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $delegateTo,
    [bool] $Remove = $false
)

$VerbosePreference = "SilentlyContinue"

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