<#
  .SYNOPSIS
  List App registrations, which had no recent user logons.

  .DESCRIPTION
  List App registrations, which had no recent user logons.

  .NOTES
  Permissions
  MS Graph (API):
  - Directory.Read.All
  - Device.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Days without user logon" } )]
    [int] $Days = 90,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph
#Connect-MgGraph
# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
#$filter='createdDateTime le ' + $lastSignInDate + 'T00:00:00Z'

"## Inactive Applications (No SignIn since at least $Days days):"
""
Invoke-RjRbRestMethodGraph -Resource "/auditLogs/SignIns" | Select-Object -Property appDisplayName,appId,createdDateTime | Group-Object -Property Id | ForEach-Object {
    $first = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1
    if($first.createdDateTime -le $lastSignInDate){
         try {
            $app = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($app.Id)" -Method Patch -body @{ notes = $(($first.createdDateTime).ToString('o')) }
        }
         catch {
             $_
         
       }
    }
}