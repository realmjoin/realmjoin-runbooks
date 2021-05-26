#Requires -Module ExchangeOnlineManagement, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [String] $PolicyName,
    [Parameter(Mandatory = $false)]
    [boolean] $ReadOnly = $true,
    [Parameter(Mandatory = $false)]
    [String] $LinkPattern = "https://*.realmjoin.com/*",
    [Parameter(Mandatory = $false)]
    [boolean] $RemovePattern = $false
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "# Safe Links Policy Runbook"
Write-Output "# Runbook initialized by $CallerName at $(Get-Date)"

$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
$TenantName = $OrganizationInitialDomainName
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName

Write-Output ""
Write-Output "# Available Safe Links Policies"
Get-SafeLinksPolicy

Write-Output ""
Write-Output "# Safe Links Settings for Policy $PolicyName"
Write-Output ""
Get-SafeLinksPolicy -Identity $PolicyName | Select-Object -ExpandProperty DoNotRewriteUrls

if (-Not $ReadOnly) {
    if ($LinkPattern -and $PolicyName) {
        if (-Not $RemovePattern) {
            Write-Output ""
            Write-Output "# Set new pattern $LinkPattern"
            Write-Output "TODO: --New-SafeLinksPolicy -Name $PolicyName -DoNotRewriteUrls 'CurrentLinks + $LinkPattern' -Confirm:$false"
        }
        else {
            Write-Output ""
            Write-Output "# Remove pattern $LinkPattern"
            Write-Output "TODO: --New-SafeLinksPolicy -Name $PolicyName -DoNotRewriteUrls 'CurrentLinks - $LinkPattern' -Confirm:$false"
        }
    }
    else {
        Write-Output ""
        Write-Output "# Error: No Pattern or no Policy to set or remove. Please specify the parameter LinkPattern."
    }
}

Write-Output ""
Write-Output "# Disconnecting from EXO..."
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Output ""
Write-Output "# End of Runbook at $(Get-Date)"

# TODO:
# * create correct LinkPatterns
# * get default/current policy name from Get-SafeLinksPolicy to get rid of parameter

