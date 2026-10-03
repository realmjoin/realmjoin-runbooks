<#
    .SYNOPSIS
    Turn password expiration on or off for this user

    .DESCRIPTION
    Sets whether the password of this user expires. Turning expiration off keeps the current password valid indefinitely, for example for service or shared accounts; turning it on restores the tenant's default expiration.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER DisablePasswordExpiration
    Yes stops the password from expiring. No applies the tenant's default expiration again.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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
                "DisplayName": "Disable password expiration?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [boolean] $DisablePasswordExpiration = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
