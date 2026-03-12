<#
    .SYNOPSIS
    Enable or disable password expiration for a user

    .DESCRIPTION
    Updates the password policy for a user in Microsoft Entra ID. This can be used to disable password expiration or re-enable the default expiration behavior.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER DisablePasswordExpiration
    If set to true, disables password expiration for the user.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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
                "DisplayName": "Disable Password Expiration?"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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
