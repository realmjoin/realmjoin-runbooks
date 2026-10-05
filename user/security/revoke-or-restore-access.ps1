<#
    .SYNOPSIS
    Block this user's sign-in and sessions, or restore access

    .DESCRIPTION
    Blocks this user from signing in and ends the current sessions, so stolen tokens stop working immediately, for example during an incident. Re-enable user lifts the block again; ended sessions are not restored.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER Revoke
    Revoke access blocks sign-in and ends the sessions. Re-enable user lets the user sign in again.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Revoke": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Re-enable user": false,
                    "Revoke access": true
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $Revoke = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
