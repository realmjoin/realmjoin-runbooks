param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $GroupName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [boolean] $Disable
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Set external mailing initialized by $CallerName for $GroupName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
 
$TenantName = $OrganizationInitialDomainName
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ($Disable -eq "True") {
        Write-Output "Disable external mailing for $GroupName"
        $Error.Clear();
		Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $true
        if (!$Error) {
            Write-Output "External mailing successfully disabled for $GroupName"
        }
        else {
            Write-Error "Couldn't disable external mailing! `r`n $Error"
        }          
    }
    else {
        Write-Output "Enabling external mailing for $GroupName"
        $Error.Clear();
		Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $false
        if (!$Error) {
            Write-Output "External mailing successfully enabled for $GroupName"
        }
        else {
            Write-Error "Couldn't enable external mailing! `r`n $Error"
        }          
    }
    Write-Output "Adjusted external mailing settings for $GroupName"
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "script ended."