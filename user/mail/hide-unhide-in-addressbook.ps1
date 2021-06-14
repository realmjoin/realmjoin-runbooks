#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] [string] $UserName,
    [bool] $hide = $false
)

try {
    Connect-RjRbExchangeOnline

    if ($hide) {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $true 
        "Mailbox $UserName is hidden."
    }
    else {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $false
        "Mailbox $UserName is not hidden."    
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}