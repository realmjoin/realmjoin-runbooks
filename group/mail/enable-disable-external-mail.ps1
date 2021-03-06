<#
  .SYNOPSIS
  Enable/disable external parties to send eMails to O365 groups.

  .DESCRIPTION
  Enable/disable external parties to send eMails to O365 groups.

  .NOTES
  Permissions: 
   Office 365 Exchange Online
   - Exchange.ManageAsApp
  Azure AD Roles
   - Exchange administrator
  Notes: Setting this via graph is currently broken as of 2021-06-28: 
   attribute: allowExternalSenders
   https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Disable": {
                "DisplayName": "Enable or Disable External Mail",
                "SelectSimple": {
                    "Enable External Mail": false,
                    "Disable External Mail": true
                }
            },
            "GroupName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupName,
    [ValidateScript( { Use-RJInterface -DisplayName "Disable external mail" } )]
    [boolean] $Disable = $false
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

