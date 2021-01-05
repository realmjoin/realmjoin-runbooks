param
(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $true)]
    [string[]] $UI_ARRAY_ApplicationObjectIds
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Output "Remove Tags from Azure AD applications initialized by $CallerName for these applications:"
Write-Output $UI_ARRAY_ApplicationObjectIds

# Requires API Permission: Applications.ReadWriteAll
$Connection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount @Connection -ServicePrincipal | OUT-NULL
$Resource = "https://graph.microsoft.com"
$Context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$AccessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($Context.Account, $Context.Environment, $Context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $Resource).AccessToken

$Endpoint = "https://graph.microsoft.com/beta/applications"
$Headers = @{
    'Authorization'          = "Bearer $AccessToken"
    'X-Requested-With'       = 'XMLHttpRequest'
    'x-ms-client-request-id' = [guid]::NewGuid()
    'x-ms-correlation-id'    = [guid]::NewGuid()
}

# Remove Tags
foreach ($ApplicationObjectId in $UI_ARRAY_ApplicationObjectIds) {
    Write-Warning "Removing Tags from: $ApplicationObjectId"
    $Body = @{
        tags = @()
    }
    $Response = Invoke-WebRequest -Headers $Headers -Body ($Body | ConvertTo-Json) -Method PATCH -Uri "$Endpoint/$ApplicationObjectId" -ContentType "application/json" -UseBasicParsing
    If (204 -eq $Response.StatusCode) {
        Write-Output "Tags removed!"
    }
    else {
        Write-Error "Failed to remove tags:"
        $Response
    }
}

Write-Host "script ended."