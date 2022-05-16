<#
  .SYNOPSIS
  Reset a user's password. 

  .DESCRIPTION
  Reset a user's password. The user will have to change it on signin.

  .NOTES
  Permissions:
  - AzureAD Role: User administrator

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
             "UserName": {
                "Hide": true
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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Enable this user object, if disabled" } )]
    [bool] $EnableUserIfNeeded = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

"## Trying to reset the password for user '$UserName'"

# Optional: Set a password for every reset. Otherwise, a random PW will be generated every time (prefered!).
[String] $initialPassword = ""

Connect-RjRbGraph

# "Find the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

if ($enableUserIfNeeded) {
    "## Enabling user sign in"
    $body = @{
        accountEnabled = $true
    }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body
}

if ($initialPassword -eq "") {
    $initialPassword = ("Reset" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
#    "Generating initial PW: $initialPassword"
}

#"Setting PW for user " + $UserName"
$body = @{
    passwordProfile = @{
        forceChangePasswordNextSignIn = $true
        password = $initialPassword
    }
}
Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null

"## Password reset successful." 
"## User will have to change PW at next login."
""
"## Password for '$UserName' has been reset to:"
"$initialPassword"
