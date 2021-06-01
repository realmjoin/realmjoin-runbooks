#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, Az.Accounts, Az.Resources, AzureAD, ExchangeOnlineManagement

Connect-RjRbAzAccount
Get-AzADUser | Format-Table | Out-String

Connect-RjRbAzureAD
Get-AzureADUser | Format-Table | Out-String

Connect-RjRbExchangeOnline
Get-EXOMailbox | Format-Table | Out-String
Disconnect-ExchangeOnline

Connect-RjRbGraph
Invoke-RjRbRestMethodGraph "/users" -OdSelect displayName | Format-Table | Out-String
