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
function Test-ModulePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$neededModule
    )
    if (-not (Get-Module -ListAvailable $neededModule)) {
        throw ($neededModule + " is not available and can not be installed automatically. Please check.")
    }
    else {
        Import-Module $neededModule
        # "Module " + $neededModule + " is available."
    }
}

Test-ModulePresent "AzureAD"
Test-ModulePresent "RealmJoin.RunbookHelper"
#endregion

#region Authentication
Connect-RjRbAzureAD
#endregion

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "SilentlyContinue"

# "Find the user object $UserName"
$targetUser = Get-AzureADUser -ObjectId $UserName 
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"

"Block user sign in"
Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false

"Revoke all refresh tokens"
Revoke-AzureADUserAllRefreshToken -ObjectId $targetUser.ObjectId

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

"User access for " + $UserName + " has been revoked."