<#
  .SYNOPSIS
  Set a users password policy to "(Do not) Expire"

  .DESCRIPTION
  Set a users password policy to "(Do not) Expire"

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "DisablePasswordExpiration": {
                "DisplayName": "Disable Password Expiration?",
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [boolean] $DisablePasswordExpiration = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if ($DisablePasswordExpiration) {
    "## Disabling password expiration for user '$UserName'"
    $body = @{ "passwordPolicies" = "DisablePasswordExpiration" }
}
else {
    "## Enabling password expiration for user '$UserName'"
    $body = @{ "passwordPolicies" = $null }
}

Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -Method Patch -Body $body | Out-Null
