#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

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
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "User $userName has no mailbox."
    }

    $trustee = Get-EXOMailbox -Identity $delegateTo -ErrorAction SilentlyContinue 
    # Check if trustee has a mailbox
    if (-not $trustee) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "Trustee $delegateTo has no mailbox."
    }

    if ($Remove) {
        #Remove permission
        Set-Mailbox -Identity $UserName -GrantSendOnBehalfTo @{Remove = "$delegateTo" } -Confirm:$false | Out-Null
        "SendOnBehalf Permission for $($trustee.UserPrincipalName) removed from mailbox $($user.UserPrincipalName)"
    }
    else {
        #Add permission
        Set-Mailbox -Identity $UserName -GrantSendOnBehalfTo @{Add = "$delegateTo" } -Confirm:$false | Out-Null
        "SendOnBehalf Permission for $($trustee.UserPrincipalName) added to mailbox  $($user.UserPrincipalName)"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}