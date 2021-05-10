#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.3.0" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $OrganizationInitialDomainName,

    [Parameter(Mandatory = $true)]
    [string] $UserName,

    [Parameter(Mandatory = $true)]
    [string] $CallerName,

    [Parameter(Mandatory = $false)]
    [datetime] $Start,

    [Parameter(Mandatory = $false)]
    [datetime] $End,

    [Parameter(Mandatory = $false)]
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string] $Message_Intern,

    [Parameter(Mandatory = $false)]
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string] $Message_Extern,

    [Parameter(Mandatory = $false)]
    [bool] $Disable
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Set Out Of Office settings initialized by $CallerName for $UserName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
 
$TenantName = $OrganizationInitialDomainName
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ($Disable -eq "True") {
        Write-Output "Disable Out Of Office settings for $UserName"
        $Error.Clear();
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled
        if (!$Error) {
            Write-Output "Out Of Office replies are removed for $UserName"
        }
        else {
            Write-Error "Couldn't remove Out Of Office replies! `r`n $Error"
        }          
    }
    else {
        Write-Output "Enabling Out Of Office settings for $UserName"
        $Error.Clear();
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled -ExternalMessage $Message_Extern -InternalMessage $Message_Intern -StartTime $Start -EndTime $End
        if (!$Error) {
            Write-Output "Out of office settings saved successfully for mailbox $UserName"
        }
        else {
            Write-Error "Couldn't set Out Of Office settings! `r`n $Error"
        }          
    }
    Write-Output "Adjusted Out Of Settings for $UserName"
    Get-MailboxAutoReplyConfiguration $UserName
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Get-PsSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' } | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "script ended."
