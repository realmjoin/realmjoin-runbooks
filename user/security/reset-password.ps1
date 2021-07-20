<#
  .SYNOPSIS
  Reset a user's password. 

  .DESCRIPTION
  Reset a user's password. The user will have to change it on singin.

  .NOTES
  Permissions:
  - AzureAD Role: User administrator

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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Enable this user object, if disabled" } )]
    [bool] $EnableUserIfNeeded = $true
)

# Optional: Set a password for every reset. Otherwise, a random PW will be generated every time (prefered!).
[String] $initialPassword = ""

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

if ($enableUserIfNeeded) {
    "## Enabling user sign in"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $true | Out-Null
}

if ($initialPassword -eq "") {
    $initialPassword = ("Reset" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
#    "Generating initial PW: $initialPassword"
}

$encPassword = ConvertTo-SecureString -String $initialPassword -AsPlainText -Force

#"Setting PW for user " + $UserName" 
Set-AzureADUserPassword -ObjectId $targetUser.ObjectId -Password $encPassword -ForceChangePasswordNextLogin $true | Out-Null

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

"## Password reset successful." 
"User will have to change PW at next login."
""
"## Password for $UserName has been reset to:"
"$initialPassword"
