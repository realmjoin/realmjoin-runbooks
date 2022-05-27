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
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"

"## Inactive Applications (Last SignIn more than $Days days ago):"
""
[array]$UsedApps = @()
try {
    Invoke-RjRbRestMethodGraph -Resource "/auditLogs/SignIns" -FollowPaging | Select-Object -Property appDisplayName, appId, createdDateTime | Group-Object -Property appId | ForEach-Object {
        $first = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1
        $UsedApps += Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"        
        if ($first.createdDateTime -le $lastSignInDate) {
            $app = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -OdFilter "appId eq '$($first.appId)'"
            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($app.Id)" -Method Patch -body @{ notes = $(($first.createdDateTime).ToString('o')) }
            $loginTime = New-TimeSpan -Start $first.createdDateTime -End (Get-Date)
            # Some apps seem to have no DisplayName...
            if ($app.appDisplayName) { 
                "## $($app.appDisplayName): no logins for $($loginTime.Days) Days"
            }
            else {
                "## (AppId) $($app.appId): no logins for $($loginTime.Days) Days"
            }
        }
    }
}
catch {
    "## Listing AuditLog or ServicePrincipals failed. Missing permissions?"
    "## Error details:"
    $_
}

""
"## Inactive Applications (No SignIn record exists in AuditLog):"
""


try {
    $AllApps = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -FollowPaging
    $unusedApps = (Compare-Object $AllApps $UsedApps).InputObject
    foreach ($app in $unusedApps) {
            # Some apps seem to have no DisplayName...
            if ($app.appDisplayName) { 
                "## $($app.appDisplayName): no logins recorded in auditLog"
            }
            else {
                "## (AppId) $($app.appId): no logins recorded in auditLog"
            }
    }
}
catch {
    "## Listing ServicePrincipals failed. Missing permissions?"
    "## Error details:"
    $_
}