#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] [string] $UserName,
    [Parameter(Mandatory = $true)] [string] $delegateTo,
    [bool] $Remove = $false
)

Connect-RjRbExchangeOnline

if ($Remove)
{
    Remove-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
    "SendAs Permission for $delegateTo removed from mailbox $UserName"
} else {
    Add-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
    "SendAs Permission for $delegateTo added to mailbox  $UserName"
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null