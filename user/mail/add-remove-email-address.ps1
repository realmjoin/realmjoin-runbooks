#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] [string] $UserName,
    [Parameter(Mandatory = $true)] [string] $eMailAddress,
    [bool] $Remove = $false,
    [bool] $asPrimary = $false
)

$VerbosePreference = "SilentlyContinue"

Connect-RjRbExchangeOnline

# Get User / Mailbox
$mailbox = Get-EXOMailbox -UserPrincipalName $UserName

if ($mailbox.EmailAddresses -icontains "smtp:$eMailAddress") {
    # eMail-Address is already present
    if ($Remove) {
        # Remove email address
        Set-Mailbox -Identity $UserName -EmailAddresses @{remove = "$eMailAddress" }
        "Alias $eMailAddress is removed from user $UserName"
    }
    else {
        "$eMailAddress is already assigned to user $UserName"
    }
} 
else {
    # eMail-Address is not present
    if (-not $Remove) {
        # Add email address    
        if ($asPrimary) {
            Set-Mailbox -Identity $UserName -EmailAddresses @{add = "SMTP:$eMailAddress" }
        }
        else {
            Set-Mailbox -Identity $UserName -EmailAddresses @{add = "$eMailAddress" }
        }
        "$eMailAddress successfully added to user $UserName"
    } else {
        "$eMailAddress is not assigned to user $UserName"
    }
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null