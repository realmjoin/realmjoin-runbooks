param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbExchangeOnline

Set-CasMailbox -OwaMailboxPolicy "OwaMbxPolicyWithBookingEnabled" -Identity $UserName

Disconnect-ExchangeOnline -Confirm:$false 