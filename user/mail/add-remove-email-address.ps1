#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] [string] $UserName,
    [Parameter(Mandatory = $true)] [string] $eMailAddress,
    [bool] $Remove = $false,
    [bool] $asPrimary = $false
)

Connect-RjRbExchangeOnline

# Get User / Mailbox
$mailbox = Get-EXOMailbox -UserPrincipalName $UserName
# Is the alias present?
foreach ($existingAddress in $mailbox.EmailAddresses) {
    if ($existingAddress -eq "smtp:$eMailAddress") {
        if ($Remove) {
            # Remove email address
            Set-Mailbox -Identity $UserName -EmailAddresses @{remove = "$eMailAddress" }
            "Alias $eMailAddress is removed from user $UserName"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
            exit
        }
        else {
            # found email address
            "$eMailAddress is already assigned to user $UserName"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
            exit
        }
    }
}

# Not removed, not found - Add email address
if ($asPrimary) {
    Set-Mailbox -Identity $UserName -EmailAddresses @{add = "SMTP:$eMailAddress" }
}
else {
    Set-Mailbox -Identity $UserName -EmailAddresses @{add = "$eMailAddress" }
}
"$eMailAddress successfully added to user $UserName."
Disconnect-ExchangeOnline -Confirm:$false | Out-Null