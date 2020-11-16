param
(
    [Parameter(Mandatory = $false)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [datetime] $UI_Date_Start,
    [Parameter(Mandatory = $false)]
    [datetime] $UI_Date_End,
    [Parameter(Mandatory = $false)]
    [string] $UI_Text_Message_Intern,
    [Parameter(Mandatory = $false)]
    [string] $UI_Text_Extern,
    [Parameter(Mandatory = $false)]
    [boolean] $Disable
)
Write-Output "Set Out Of Office settings initialized by $CallerName for $UserPrincipalName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
 
$TenantName = "c4a8.onmicrosoft.com" # Get-AutomationVariable -Name 'tbd'
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ($Disable -eq "True") {
        Write-Output "Disable Out Of Office settings for $UserPrincipalName"
        $Error.Clear();
        Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Disabled
        if (!$Error) {
            Write-Output "Out Of Office replies are removed for $UserPrincipalName"
        }
        else {
            Write-Error "Couldn't remove Out Of Office replies! `r`n $Error"
        }          
    }
    else {
        Write-Output "Enabling Out Of Office settings for $UserPrincipalName"
        $Error.Clear();
        Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Scheduled -ExternalMessage $Message_Extern -InternalMessage $Message_Intern -StartTime $UI_Date_Start -EndTime $UI_Date_End
        if (!$Error) {
            Write-Output "Out of office settings saved successfully for mailbox $UserPrincipalName"
        }
        else {
            Write-Error "Couldn't set Out Of Office settings! `r`n $Error"
        }          
    }
    Write-Output "Adjusted Out Of Settings for $UserPrincipalName"
    Get-MailboxAutoReplyConfiguration $UserPrincipalName
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession

Write-Host "script ended."
