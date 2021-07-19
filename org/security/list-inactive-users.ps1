<#
  .SYNOPSIS
  List users, that have no recent signins.

  .DESCRIPTION
  List users, that have no recent signins.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - AuditLogs.Read.All
  - Organization.Read.All
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Days without signin" } )]
    [int] $Days = 30
)

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter='signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'

Invoke-RjRbRestMethodGraph -Resource '/users' -OdFilter $filter -Beta | Select-Object -Property UserPrincipalName,signInSessionsValidFromDateTime | out-string