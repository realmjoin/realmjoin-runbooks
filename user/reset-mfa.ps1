param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Reset Multi-Factor Authentication Office settings initialized by $CallerName for $UserName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL

$credObject = Get-AutomationPSCredential -Name "Office-Credentials" | OUT-NULL
Connect-MsolService -Credential $credObject | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Azure AD MSOL Powershell established!"    
    Write-Output "Enabling Out Of Office settings for $UserName"
    $Error.Clear();
    Set-MSOLUser -UserPrincipalName $UserName -StrongAuthenticationMethods @()
    if (!$Error) {
            Write-Output "MFA settings reset successfully for  $UserName"
        }
        else {
            Write-Error "Couldn't reset MFA settings! `r`n $Error"
        }
    Write-Output "Resetted MFA Settings for $UserName"
    }
else {
    Write-Error "Connection to Azure AD failed! `r`n $Error"
}

# There is no disconnect for MSOLService

Write-Host "script ended."
