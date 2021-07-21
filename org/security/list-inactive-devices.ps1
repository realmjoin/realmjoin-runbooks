<#
  .SYNOPSIS
  List devices, which had no recent user logons.

  .DESCRIPTION
  List devices, which had no recent user logons.

  .NOTES
  Permissions
  MS Graph (API):
  - Directory.Read.All
  - Device.Read.All
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Days without user logon" } )]
    [int] $Days = 30
)

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter='approximateLastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'

"## Inactive Devices (No SignIn since at least $Days days):"
""
Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter $filter | Select-Object -Property displayName,deviceId,approximateLastSignInDateTime | out-string

