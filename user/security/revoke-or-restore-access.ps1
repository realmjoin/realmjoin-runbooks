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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $Revoke = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

# "Find the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -resource "/users/$UserName" -ErrorAction SilentlyContinue 
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

# "Block/Enable user sign in"
$body = @{
    accountEnabled = (-not $Revoke)
}
Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null

if ($Revoke) {
    # "Revoke all refresh tokens"
    $body = @{ }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/revokeSignInSessions" -Method Post -Body $body | Out-Null
    "## User access for " + $UserName + " has been revoked."
}
else {
    "## User " + $UserName + " has been enabled."
}
