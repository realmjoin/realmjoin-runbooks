param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [string] $UI_Text_Additional_Alias,
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Add an initial e-Mail address (Alias) initialized by $CallerName for $UserName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
#Get Graph Credentials 

$TenantName = $OrganizationInitialDomainName
Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $TenantName | OUT-NULL

function IsExchangeAliasUnique($exchangeAlias)
{
    $domainName = $Context.GetObjectDomain("%distinguishedName%")

#    Search all aliases
#    https://graph.microsoft.com/beta/users?$filter=otherMails/any(x:x eq 'xxx@abc.com')
#    if($users.Count -eq 0)
#    {
#       return $True
#    }
#    return $False
}

Function Get-GraphResponse {
    param(
        [parameter(Mandatory = $true)]
        $Url
    )
    try {
        $appCredentials = Get-AutomationPSCredential -Name 'ServicePrincipalGkCsoc'
    }
    catch {
        throw "Automation Credential not set!"
        return $false
    }
    try {
        $tenantId = $TenantInformation.id
    }
    catch {
        throw "tenants.json incosistent!"
        return $false
    }
    try {
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $appCredentials.GetNetworkCredential().UserName
            client_secret = $appCredentials.GetNetworkCredential().password
            scope         = "https://graph.microsoft.com/.default"
        }
        $requestSplat = @{
            ContentType = 'application/x-www-form-urlencoded'
            Method      = 'POST'
            Body        = $body
            Uri         = $tokenEndpoint
        }
        $AccessToken = (Invoke-RestMethod @requestSplat).access_token
        $header = @{
            'Authorization' = "Bearer $AccessToken"
        }
    }
    catch {
        throw $_.Exception
    }
    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $header -Method Get -ContentType "application/json"
        return $response
    }catch {
        return $_.Exception.Response.StatusCode.value__
    }
}


if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if ((IsExchangeAliasUnique($UI_Text_Additional_Alias)) {
        Write-Output "New Alias will be added to $UserName"
        $Error.Clear();
        Set-RemoteMailBox -Identity $UserName -EmailAddresses @{Add='$UI_Text_Additional_Alias'}
        if (!$Error) {
            Write-Output "New Alias $UI_Text_Additional_Alias was added for $UserName"
        }
        else {
            Write-Error "Couldn't add additional alias! `r`n $Error"
        }          
    }
    else {
        Write-Output "Alias $UI_Text_Additional_Alias is not unique!"
        $Error.Clear();          
    }
    Write-Output "Adjusted Out Of Settings for $UserName"
    Get-MailboxAutoReplyConfiguration $UserName
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "script ended."
