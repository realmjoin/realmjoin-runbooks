<#
  .SYNOPSIS
  (Un)hide an O365- or static Distribution-group in Address Book.

  .DESCRIPTION
  (Un)hide an O365- or static Distribution-group in Address Book. Can also show the current state.

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
            "Action": {
                "DisplayName": "Show or Hide Group in Address Book",
                "SelectSimple": {
                    "Show Group in Address Book": 0,
                    "Hide Group from Address Book": 1,
                    "Query current state": 2
                }
            },
            "GroupName": {
                "Hide": true
            },
            "CallerName": {
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
    [int] $Action = 1,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

try {
    $ProgressPreference = "SilentlyContinue"

    Connect-RjRbExchangeOnline

    $group = Get-UnifiedGroup -Identity $GroupName -ErrorAction SilentlyContinue
    $groupType = 0

    # "Checking"  if group is universal or distribution group
    if (-not $group) {
        $group = Get-DistributionGroup -Identity $GroupName -ErrorAction SilentlyContinue
        $groupType = 1
        if (-not $group) {
            "## `'$GroupName`' is not a unified (O365)- or distribution group."
            ""
            throw ("Group not found.")
        }
    }
    
    if ($Action -le 1) {
        try {
            if ($Action -eq 0) {
                if ($groupType -eq 0) {
                    Set-UnifiedGroup -Identity $GroupName -HiddenFromAddressListsEnabled $false
                }
                else {
                    Set-DistributionGroup -Identity $GroupName -HiddenFromAddressListsEnabled $false
                }
                "## '$GroupName' successfully made visible."    
            }
            if ($Action -eq 1) {
                if ($groupType -eq 0) {
                    Set-UnifiedGroup -Identity $GroupName -HiddenFromAddressListsEnabled $true
                }
                else {
                    Set-DistributionGroup -Identity $GroupName -HiddenFromAddressListsEnabled $true
                }
                "## '$GroupName' successfully hidden."
            }
        }
        catch {
            throw "Couldn't modify '$GroupName'"
        }
    }
    else {
        "## '$GroupName' is currently hidden: $($group.HiddenFromAddressListsEnabled)"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}

