# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

# Required modules. Will be honored by Azure Automation.
using module AzureAD

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName
)

$connectionName = "AzureRunAsConnection"

# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

write-output "Authenticate to AzureAD with AzureRunAsConnection..." 
try {
    Connect-AzureAD -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -ApplicationId $servicePrincipalConnection.ApplicationId -TenantId $servicePrincipalConnection.TenantId | Out-Null
}
catch {
    Write-Error $_.Exception
    throw "AzureAD login failed"
}

write-output ("Find the user object " + $UserName) 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

Write-Output "Block user sign in"
Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false

Write-Output "Revoke all refresh tokens"
Revoke-AzureADUserAllRefreshToken -ObjectId $targetUser.ObjectId

Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false
