# This runbook will enable/disable external parties to send emails to O365 groups.
#
# Permissions: 
#  Office 365 Exchange Online
#  - Exchange.ManageAsApp
#
# Azure AD Roles
#  - Exchange administrator

#Requires -Module ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupName,
    [boolean] $Hide = $false
)

try {
    $ProgressPreference = "SilentlyContinue"

    Connect-RjRbExchangeOnline

    # "Checking"  if group is universal group
    if (-not (Get-UnifiedGroup -Identity $GroupName -ErrorAction SilentlyContinue)) {
        throw "`'$GroupName`' is not a unified (O365) group. Can not proceed."
    }
    
    try {
        Set-UnifiedGroup -Identity $GroupName -HiddenFromAddressListsEnabled $Hide
    }
    catch {
        throw "Couldn't modify '$GroupName'"
    }
    "'$GroupName' successfully updated."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}

