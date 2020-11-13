param
(
    [Parameter(Mandatory = $true)]
    [String] $UserPrincipalName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [datetime] $Datetime_Start,
    [Parameter(Mandatory = $false)]
    [datetime] $Datetime_End,
    [Parameter(Mandatory = $false)]
    [string] $String_MessageIntern,
    [Parameter(Mandatory = $false)]
    [string] $String_MessageExtern,
    [Parameter(Mandatory = $false)]
    [String] $String_Disable
)
Write-Output "Set Out Of Office settings initialized by $CallerName for $UserPrincipalName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
 
$TenantName = "c4a8.onmicrosoft.com" # Get-AutomationVariable -Name 'tbd'
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL
if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ($String_Disable -eq "True") {
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
        Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Scheduled -ExternalMessage $String_MessageExtern -InternalMessage $String_MessageIntern -StartTime $Datetime_Start -EndTime $Datetime_End
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