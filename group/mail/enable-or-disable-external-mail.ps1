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
            "Action": {
                "DisplayName": "Choose action",
                "SelectSimple": {
                    "Enable External Mail": 0,
                    "Disable External Mail": 1,
                    "Query current state only": 2
                }
            },
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupId,
    [int] $Action = 0,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    $ProgressPreference = "SilentlyContinue"

    Connect-RjRbExchangeOnline

    # "Checking"  if group is universal group
    $group = Get-UnifiedGroup -Identity $GroupId -ErrorAction SilentlyContinue
    if (-not $group) {
        throw "`'$GroupId`' is not a unified (O365) group. Can not proceed."
    }
    
    if ($Action -eq 1) {
        # "Disable external mailing for $GroupId"
        try {
            Set-UnifiedGroup -Identity $GroupId -RequireSenderAuthenticationEnabled $true
        }
        catch {
            throw "Couldn't disable external mailing! `r`n $_"
        }
        "## External mailing successfully disabled for '$($group.displayName)'"
    }
    
    if ($Action -eq 0) {
        # "Enabling external mailing for $GroupId"
        try {
            Set-UnifiedGroup -Identity $GroupId -RequireSenderAuthenticationEnabled $false
        }
        catch {
            throw "Couldn't enable external mailing! `r`n $_"
        }
        "## External mailing successfully enabled for '$($group.displayName)'"
    }

    if ($Action -eq 2) {
        "## External Mailing for group '$($group.displayName)' is enabled: $( -not (Get-UnifiedGroup -Identity $GroupId).RequireSenderAuthenticationEnabled)"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}

