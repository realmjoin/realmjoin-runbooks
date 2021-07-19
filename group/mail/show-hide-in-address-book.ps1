<#
  .SYNOPSIS
  (Un)hide this group in Address Book.

  .DESCRIPTION
  (Un)hide this group in Address Book.

  .NOTES
  Permissions: 
   Office 365 Exchange Online
   - Exchange.ManageAsApp
   Azure AD Roles
   - Exchange administrator
   Note, as of 2021-06-28 MS Graph does not support updating existing groups - only on initial creation.
    PATCH : https://graph.microsoft.com/v1.0/groups/{id}
    body = { "resourceBehaviorOptions":["HideGroupInOutlook"] }

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Hide": {
                "DisplayName": "Show or Hide Group in Address Book",
                "SelectSimple": {
                    "Show Group in Address Book": false,
                    "Hide Group from Address Book": true
                }
            },
            "GroupName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupName,
    [ValidateScript( { Use-RJInterface -DisplayName "Hide Group in Address Book" } )]
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

