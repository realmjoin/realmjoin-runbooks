# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

#Requires -Modules AzureAD, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $enableUserIfNeeded = $true
)

# Optional: Set a password for every reset. Otherwise, a random PW will be generated every time (prefered!).
[String] $initialPassword = ""

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

write-output ("Find the user object " + $UserName) 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

if ($enableUserIfNeeded) {
    Write-Output "Enable user sign in"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $true
}

if ($initialPassword -eq "") {
    $initialPassword = ("Reset" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
    Write-Output ("Generating initial PW: " + $initialPassword)
}

$encPassword = ConvertTo-SecureString -String $initialPassword -AsPlainText -Force

Write-Output ("Setting PW for user " + $UserName + ". User will have to change PW at next login.")
Set-AzureADUserPassword -ObjectId $targetUser.ObjectId -Password $encPassword -ForceChangePasswordNextLogin $true

Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

Write-Output ("Password for " + $UserName + " has been reset to: " + $initialPassword)
