param
(
    [Parameter(Mandatory = $true)]
    [string] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [string] $OrganizationId,
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $Additional_Alias
)

Set-StrictMode -Version Latest
#$ErrorActionPreference = "Stop"
#$ProgressPreference = "SilentlyContinue"
$GLOBAL:DebugPreference="Continue"  

Write-Output "Add an initial e-Mail address (Alias) initialized by $CallerName for $UserName"
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection' 
$Connection

#Debug Connect-AzAccount @Connection -ServicePrincipal 5>&1
Connect-AzAccount @Connection -ServicePrincipal 

Write-Output "After Connect-azaccount"  $Error.Count
$Error


#$appCredentials = Get-AutomationPSCredential -Name 'rj-serviceprincipal'

#Connect-ExchangeOnline -CertificateThumbprint $Connection.CertificateThumbprint -AppId $Connection.ApplicationId -Organization $OrganizationInitialDomainName 

Function Get-GraphResponse {
    param(
        [parameter(Mandatory = $true)]
        $Url
    )
    try {
        $tokenEndpoint = "https://login.microsoftonline.com/$OrganizationId/oauth2/v2.0/token"
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

Write-Output "before IsExchangeAliasUnique "
$Error.Count

Function IsExchangeAliasUnique($exchangeAlias) {
#    Search all aliases
    Write-Output "before getgraph"
    $graph=    Get-GraphResponse -Url "https://graph.microsoft.com/beta/users?`$filter=proxyAddresses/any(x:startswith(x, 'smtp:$Additional_Alias')) or userPrincipalName eq '$Additional_Alias' or mail eq '$Additional_Alias')"
    Write-Output $graph
    Write-Output "getgraph output"

    Get-GraphResponse -Url "https://graph.microsoft.com/beta/users?`$filter=proxyAddresses/any(x:startswith(x, 'smtp:$Additional_Alias')) or userPrincipalName eq '$Additional_Alias' or mail eq '$Additional_Alias')"

#    if($users.Count -eq 0)
#    {
#       return $True
#    }
#    return $False
#
}

$Error.Count

if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if (IsExchangeAliasUnique($Additional_Alias)) {
        Write-Output "New Alias will be added to $UserName"
        $Error.Clear();
        Set-RemoteMailBox -Identity $UserName -EmailAddresses @{Add='$Additional_Alias'}
        if (!$Error) {
            Write-Output "New Alias $Additional_Alias was added for $UserName"
        }
        else {
            Write-Error "Couldn't add additional alias! `r`n $Error"
        }          
    }
    else {
        Write-Output "Alias $Additional_Alias is not unique!"
        $Error.Clear();          
    }
    Write-Output "Adjusted Out Of Settings for $UserName"
}
else {
    Write-Error "99 Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Write-Output "------ " (get-date).ToString('T') "--------------------------------------------------------------------------------------------------------"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "script ended."
