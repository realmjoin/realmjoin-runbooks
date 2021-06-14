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
    [boolean] $Disable
)

try {
    $ProgressPreference = "SilentlyContinue"

    Connect-RjRbExchangeOnline

    # "Checking"  if group is universal group
    if (-not (Get-UnifiedGroup -Identity $GroupName -ErrorAction SilentlyContinue)) {
        throw "`'$GroupName`' is not a unified (O365) group. Can not proceed."
    }
    
    if ($Disable) {
        # "Disable external mailing for $GroupName"
        try {
            Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $true
        }
        catch {
            throw "Couldn't disable external mailing! `r`n $_"
        }
        "External mailing successfully disabled for `'$GroupName`'"
    }
    
    else {
        # "Enabling external mailing for $GroupName"
        try {
            Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $false
        }
        catch {
            throw "Couldn't enable external mailing! `r`n $_"
        }
        "External mailing successfully enabled for `'$GroupName`'"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}

