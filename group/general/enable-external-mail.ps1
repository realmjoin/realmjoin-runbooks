# This runbook will enable/disable external parties to send emails to O365 groups.
#
# Permissions: 
#  Office 365 Exchange Online
#  - Exchange.ManageAsApp
#
# Azure AD Roles
#  - Exchange administrator

#Requires -Module ExchangeOnlineManagement, RealmJoin.RunbookHelper

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupName,
    [boolean] $Disable,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

#region module check
$neededModule = "ExchangeOnlineManagement"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

#region authentication
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
# "Connecting to Exchange online."
try {
    Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $OrganizationInitialDomainName | Out-Null
}
catch {
    throw "Connection to Exchange Online failed! `r`n $_"
}
# "Connection to Exchange Online Powershell established!"  
#endregion

# "Checking"  if group is universal group
if (-not (Get-UnifiedGroup -Identity $GroupName -ErrorAction SilentlyContinue)) {
    throw "`'$GroupName`' is not a unified (O365) group. Can not proceed."
}
    
if ($Disable) {
    # "Disable external mailing for $GroupName"
    try {
        Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $true
    }
    catch {
        throw "Couldn't disable external mailing! `r`n $_"
    }
    "External mailing successfully disabled for `'$GroupName`'"
}
    
else {
    # "Enabling external mailing for $GroupName"
    try {
        Set-UnifiedGroup -Identity $GroupName -RequireSenderAuthenticationEnabled $false
    }
    catch {
        throw "Couldn't enable external mailing! `r`n $_"
    }
    "External mailing successfully enabled for `'$GroupName`'"
}

# "Disconnecting from EXO"
Get-PsSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' } | Remove-PsSession | Out-Null
Disconnect-ExchangeOnline -Confirm:$false | Out-Null

