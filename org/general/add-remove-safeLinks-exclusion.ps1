#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

<#
  .SYNOPSIS
  Will add or remove a SafeLinks URL exclusion to/from a given policy.

  .DESCRIPTION
  Will add or remove a SafeLinks URL exclusion to/from a given policy.

  .PARAMETER LinkPattern
  URL to allow, can contain '*' as wildcard for host and paths

  .PARAMETER PolicyName
  Optional if only one exists.
#>

param(
    # Not mandatory to allow an example value
    [String] $LinkPattern = "https://*.microsoft.com/*",
    # If only one policy exists, no need to specify
    [ValidateScript( { Use-RJInterface -DisplayName "Safe Links policy name" } )]
    [String] $PolicyName,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this pattern" } )]
    [boolean] $RemovePattern = $false

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
        throw "Please give a SafeLinks Policy."
    }

    $DoNotRewriteUrls = @()
    if ($RemovePattern) {
        foreach ($entry in $policy.DoNotRewriteUrls) {
            if ($entry -ne $LinkPattern) {
                $DoNotRewriteUrls += $entry
            } 
        }
    }
    else {
        $DoNotRewriteUrls = $policy.DoNotRewriteUrls + $LinkPattern | Sort-Object -Unique
    }

    Set-SafeLinksPolicy -Identity $policy.Id -DoNotRewriteUrls $DoNotRewriteUrls | Out-Null

    "Policy $PolicyName successfully updated."

}
finally {
    Disconnect-ExchangeOnline -confirm:$false | Out-Null
}