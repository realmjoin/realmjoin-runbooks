# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - User.ReadWrite.All, Directory.ReadWrite.All,

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName
)

Connect-RjRbAzureAD

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "SilentlyContinue"

# "Find the user object $UserName"
$targetUser = Get-AzureADUser -ObjectId $UserName 
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"

# "Block user sign in"
Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false | Out-Null

# "Revoke all refresh tokens"
Revoke-AzureADUserAllRefreshToken -ObjectId $targetUser.ObjectId | Out-Null

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null

"User access for " + $UserName + " has been revoked."