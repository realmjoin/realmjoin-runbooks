<#
    .SYNOPSIS
    Revoke or restore user access

    .DESCRIPTION
    Blocks or re-enables a user account and optionally revokes active sign-in sessions. This can be used during incident response to immediately invalidate user tokens.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER Revoke
    If set to true, blocks sign-in and revokes sessions. If set to false, re-enables sign-in.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $Revoke = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if ($Revoke) {
    "## Trying to revoke access and block signin for user '$UserName'."
}
else {
    "## Trying to enable signing for user '$UserName'."
}

# "Find the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -resource "/users/$UserName" -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User '$UserName' not found.")
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
    "## User access for '$UserName' has been revoked."
}
else {
    "## User '$UserName' has been enabled."
}
