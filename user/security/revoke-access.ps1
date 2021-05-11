# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - User.ReadWrite.All, Directory.ReadWrite.All,

#Requires -Modules AzureAD, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName
)

#region module check
$neededModule = "AzureAD"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

#region Authentication
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
#endregion

#region main script
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

Write-Output ("User access for " + $UserName + " has been revoked.")
#endregion