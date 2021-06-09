# This will list all users that have not signed in in at least the given number of days
#
# Permissions: MS Graph
# - AuditLogs.Read.All
# - Organization.Read.All

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [int] $Days = 30
)

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter='signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'

Invoke-RjRbRestMethodGraph -Resource '/users' -OdFilter $filter -Beta | Select-Object -Property UserPrincipalName,signInSessionsValidFromDateTime | out-string