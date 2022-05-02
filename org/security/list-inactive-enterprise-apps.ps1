<#
  .SYNOPSIS
  List App registrations, which had no recent user logons.

  .DESCRIPTION
  List App registrations, which had no recent user logons.

  .NOTES
  Permissions
  MS Graph (API):
  - Application.ReadWrite.All
  - AuditLog.Read.All 
  - Directory.Read.All

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
# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
#$filter='createdDateTime le ' + $lastSignInDate + 'T00:00:00Z'

"## Inactive Applications (No SignIn since at least $Days days):"
""
[array]$UsedApps = @()
Invoke-RjRbRestMethodGraph -Resource "/auditLogs/SignIns" -FollowPaging | Select-Object -Property appDisplayName,appId,createdDateTime | Group-Object -Property appId | ForEach-Object {
    $first = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1
    $app = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
    if ($app) {
        $UsedApps += Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
    }

    if($first.createdDateTime -le $lastSignInDate){
         try {
            if ($app) { 
            $app = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($app.Id)" -Method Patch -body @{ notes = $(($first.createdDateTime).ToString()) }
            } else {
                "## AppId $($first.appId) not found"
            }
            $loginTime = New-TimeSpan -Start $first.createdDateTime -End (Get-Date) 
            "## $($app.appDisplayName) ($($app.appId)) no logins for $($loginTime.Days) Days"
        }
         catch {
             $_
         
       }
    }
}

try {

    $AllApps = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -FollowPaging
    $unusedApps = (Compare-Object $AllApps $UsedApps).InputObject
    ""
    "## No Login found:"
    foreach($unusedApp in $unusedApps){
        "## $($unusedApp.appDisplayName) ($($app.appId))"
    }
}
catch {
    $_
}