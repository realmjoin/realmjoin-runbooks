#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, Az.Accounts, Az.Resources, AzureAD, ExchangeOnlineManagement

Connect-RjRbAzAccount
Get-AzADUser | Format-Table | Out-String

Connect-RjRbAzureAD
Get-AzureADUser | Format-Table | Out-String

Connect-RjRbExchangeOnline
Get-EXOMailbox | Format-Table | Out-String
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue

Connect-RjRbGraph
Invoke-RjRbRestMethodGraph "/users" -OdSelect displayName | Format-Table | Out-String
Invoke-RjRbRestMethodGraph "/users/91ae5a52-67f6-4265-bbe5-b62268944675" | Format-List | Out-String
