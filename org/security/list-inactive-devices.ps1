#This runbook will will list devices, which no recent user logons
#
# Permissions: MS Graph
#

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param(
    [int] $Days = 30
)

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter='approximateLastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'

Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter $filter | Select-Object -Property displayName,deviceId,approximateLastSignInDateTime | out-string

