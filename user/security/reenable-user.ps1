<#
  .SYNOPSIS
  Enable a user object (after revoking access).

  .DESCRIPTION
  Enable a user object (after revoking access).

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
            }
        }
    }

#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

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
Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $true | Out-Null

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null

"## User " + $UserName + " has been enabled."