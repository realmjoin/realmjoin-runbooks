<#
    .SYNOPSIS
    Reset a user's password

    .DESCRIPTION
    Resets the password for a user in Microsoft Entra ID and optionally enables the account first. The user can be forced to change the password at the next sign-in. This runbook is useful for helpdesk scenarios where a technician needs to reset a user's password and ensure that the user updates it upon next login.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER EnableUserIfNeeded
    If set to true, enables the user account before resetting the password.

    .PARAMETER ForceChangePasswordNextSignIn
    If set to true, forces the user to change the password at the next sign-in.

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
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $EnableUserIfNeeded = $true,
    [bool] $ForceChangePasswordNextSignIn = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
        forceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn
        password                      = $initialPassword
    }
}
Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null

"## Password reset successful."
if ($ForceChangePasswordNextSignIn) {
    "## User will have to change PW at next login."
}
""
"## Password for '$UserName' has been reset to:"
"$initialPassword"
