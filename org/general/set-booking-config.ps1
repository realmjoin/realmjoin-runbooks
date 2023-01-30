param(
        # CallerName is tracked purely for auditing purposes
        [Parameter(Mandatory = $true)]
        [string] $CallerName    
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbExchangeOnline

Set-OrganizationConfig -BookingsEnabled $true
"## Bookings set to 'enabled'"

Disconnect-ExchangeOnline -Confirm:$false 