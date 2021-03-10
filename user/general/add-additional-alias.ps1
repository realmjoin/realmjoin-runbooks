#Requires -Modules Az.Accounts,ExchangeOnline

param
(
    [Parameter(Mandatory = $false)]
    [string] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $false)]
    [string] $OrganizationId,
    [Parameter(Mandatory = $false)]
    [string] $UserName,
    [Parameter(Mandatory = $false)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $Additional_Alias
)

#Set-StrictMode -Version Latest
#$ErrorActionPreference = "Stop"
#$ProgressPreference = "SilentlyContinue"
#$GLOBAL:DebugPreference="Continue"  

$OrganizationId = "81a3ef22-4447-4627-91ae-6774f48748d1"
$connectionName = "AzureRunAsConnection"
$LogType = "AutomationAppConnecting"
$ErrorMessage = ""
$Exception = ""
$desc = ""

$connectionname = "AzureRunAsConnection"
$appCredentials = Get-AutomationPSCredential -Name 'rj-serviceprincipal'

try
{
    # Get the connection "AzureRunAsConnection"
    
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    $tenantId = $servicePrincipalConnection.TenantId
    $AzureAPPID = $servicePrincipalConnection.ApplicationId
    $subID = $servicePrincipalConnection.SubscriptionId
    $runBookJobID = $PSPrivateMetadata.JobId.Guid
    $certificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $desc = "[INFO] Logging in to Azure.... RunBook Job ID:[$runBookJobID]`r`n"
        Connect-AzAccount -ServicePrincipal -Tenant $tenantId -ApplicationId $AzureAPPID -CertificateThumbprint $certificateThumbprint
} catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        $Exception = $_.Exception
        Write-Error -Message $Exception
        throw $Exception
    }
} finally {
    $desc += "AzureAPPID:[$AzureAPPID] in TenantId:[$tenantId], Sub ID[$subID]. Errors:[$ErrorMessage] Exception:[$Exception]"
    $desc
    $Error.Clear()
}


Function Get-GraphResponse {
    param(
        [parameter(Mandatory = $true)]
        $Url
        )
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
        $Url
        $response = Invoke-RestMethod -Uri $Url -Headers $header -Method Get -ContentType "application/json"
        return $response.value
}


Function IsExchangeAliasUnique($exchangeAlias) {
#    Search all aliases
    Write-Output "before getgraph"
    $graph= Get-GraphResponse -Url "https://graph.microsoft.com/beta/users?`$filter=proxyAddresses/any(x:startswith(x, 'smtp:$Additional_Alias')) or userPrincipalName eq '$Additional_Alias' or mail eq '$Additional_Alias')"
    Write-Output $graph
    Write-Output "getgraph output"
    #Get-GraphResponse -Url "https://graph.microsoft.com/beta/users?`$filter=proxyAddresses/any(x:startswith(x, 'smtp:$Additional_Alias')) or userPrincipalName eq '$Additional_Alias' or mail eq '$Additional_Alias')"
}



if (!$Error) {
    Write-Output "Connection to Exchange Online Powershell established!"    
    if (IsExchangeAliasUnique($Additional_Alias)) {
        Write-Output "New Alias will be added to $UserName"
        #Set-RemoteMailBox -Identity $UserName -EmailAddresses @{Add='$Additional_Alias'}
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
    Write-Output "Added additional alias  for $UserName"
}
else {
    Write-Error "Connection to Exchange Online failed! `r`n $Error"
}

Write-Output "Disconnect from EXO"
Write-Output "------ " (get-date).ToString('T') "--------------------------------------------------------------------------------------------------------"
Get-PsSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'} | Remove-PsSession
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "script ended."

