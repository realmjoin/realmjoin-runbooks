<#
  .SYNOPSIS
  Disable or a user and revoke all tokens or re-enable this user.

  .DESCRIPTION
  Disable or a user and revoke all tokens or re-enable this user.

  .NOTES
  Permissions:
  MS Graph (API)
  - User.ReadWrite.All, Directory.ReadWrite.All,
  AzureAD Roles
  - User Administrator
  
  .INPUTS
  RunbookCustomization: {
        "Parameters": {
             "UserName": {
                "Hide": true
            },
            "Revoke": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "(Re-)Enable User": false,
                    "Revoke Access": true
                } 
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $Revoke = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
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

# "Block/Enable user sign in"
Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled (-not $Revoke) | Out-Null

if ($Revoke) {
    # "Revoke all refresh tokens"
    Revoke-AzureADUserAllRefreshToken -ObjectId $targetUser.ObjectId | Out-Null

    "## User access for " + $UserName + " has been revoked."
}
else {
    "## User " + $UserName + " has been enabled."
}

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null
