#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  List devices, which had no recent user logons.

  .DESCRIPTION
  List devices, which had no recent user logons.
#>

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Days without user logon" } )]
    [int] $Days = 30
)

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter='approximateLastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'

Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter $filter | Select-Object -Property displayName,deviceId,approximateLastSignInDateTime | out-string

