<#
  .SYNOPSIS
  Set a users password policy to "(Do not) Expire"

  .DESCRIPTION
  Set a users password policy to "(Do not) Expire"

  .NOTES
  Permissions needed:
   MS Graph (API Permissions):
   - User.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
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
    [ValidateScript( { Use-RJInterface -DisplayName "Disable Password Expiration?"} )]
    [boolean] $DisablePasswordExpiration = $true
)

Connect-RjRbGraph

if ($DisablePasswordExpiration) {
    "## Disabling password expiration for user '$UserName'"
    $body = @{ "passwordPolicies" = "DisablePasswordExpiration" }
} else {
    "## Enabling password expiration for user '$UserName'"
    $body = @{ "passwordPolicies" = $null }
}

Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -Method Patch -Body $body | Out-Null
