#Requires -Module ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [boolean] $Disable
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Set private initialized by $CallerName for $GroupName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
 
$TenantName = $OrganizationInitialDomainName
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ($Disable -eq "True") {
        Write-Output "Set $GroupName public"
        $Error.Clear();
		Set-UnifiedGroup -Identity $GroupName -AccessType Public
        if (!$Error) {
            Write-Output "Set $GroupName public successful."
        }
        else {
            Write-Error "Couldn't set $GroupName public! `r`n $Error"
        }          
    }
    else {
        Write-Output "Set $GroupName private"
        $Error.Clear();
		Set-UnifiedGroup -Identity $GroupName -AccessType Private
        if (!$Error) {
            Write-Output "Set $GroupName private successful."
        }
        else {
            Write-Error "Couldn't set $GroupName public! `r`n $Error"
        }          
    }
    Write-Output "Adjusted private setting $GroupName"
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "script ended."