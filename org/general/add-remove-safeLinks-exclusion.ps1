<#
  .SYNOPSIS
  Add or remove a SafeLinks URL exclusion to/from a given policy.

  .DESCRIPTION
  Add or remove a SafeLinks URL exclusion to/from a given policy.

  .PARAMETER LinkPattern
  URL to allow, can contain '*' as wildcard for host and paths

  .PARAMETER PolicyName
  Optional if only one exists.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Add or Remove URL Pattern to/from Policy",
                "SelectSimple": {
                    "Add URL Pattern to Policy": false,
                    "Remove URL Pattern from Policy": true
                }
            }
        }
    }
#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

param(
    # Not mandatory to allow an example value
    [String] $LinkPattern = "https://*.microsoft.com/*",
    # If only one policy exists, no need to specify
    [ValidateScript( { Use-RJInterface -DisplayName "Safe Links policy name" } )]
    [String] $PolicyName,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this pattern" } )]
    [boolean] $Remove = $false
)

try {
    Connect-RjRbExchangeOnline

    $policy = $null
    if ($PolicyName) {
        # "Use the given policy $PolicyName"
        $policy = Get-SafeLinksPolicy -Identity $PolicyName -ErrorAction SilentlyContinue
    }
    else {
        # If there is only one policy - use it
        $policies = [array](Get-SafeLinksPolicy -ErrorAction SilentlyContinue)
        if (($policies).count -eq 1) {
            $policy = $policies[0]
        }
    }
    if (-not $policy) {
        throw "No policy found. Please provide a SafeLinks policy."
    }

    "Policy is defined as $policy"
    "------------------------------------------------------------------------------------------------------------------------"
    Get-SafeLinksPolicy -Identity $policy.Id | Format-Table Name,IsEnabled,IsDefault


    "Current list of excluded Safe Links"
    "------------------------------------------------------------------------------------------------------------------------"
    Get-SafeLinksPolicy -Identity $policy.Id | select -expandproperty DoNotRewriteUrls

    ""
    $DoNotRewriteUrls = @()
    if ($Remove) {
    "Trying to remove $LinkPattern ..."
        foreach ($entry in $policy.DoNotRewriteUrls) {
            if ($entry -ne $LinkPattern) {
                $DoNotRewriteUrls += $entry
            } 
        }
    }
    else {
    "Trying to add $LinkPattern ..."
        $DoNotRewriteUrls = $policy.DoNotRewriteUrls + $LinkPattern | Sort-Object -Unique
    }
    Set-SafeLinksPolicy -Identity $policy.Id -DoNotRewriteUrls $DoNotRewriteUrls | Out-Null
    "Policy $policy successfully updated."

    ""
    "Safe Link Policy Dump"
    "------------------------------------------------------------------------------------------------------------------------"
    Get-SafeLinksPolicy -Identity $policy.Id | fl

}
finally {
    Disconnect-ExchangeOnline -confirm:$false | Out-Null
}