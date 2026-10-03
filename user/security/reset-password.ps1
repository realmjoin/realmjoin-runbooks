<#
    .SYNOPSIS
    Set a new password for this user

    .DESCRIPTION
    Sets a new password for this user in Entra ID and shows it in the output. A disabled account can be enabled first, and the user can be made to choose their own password at the next sign-in.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER EnableUserIfNeeded
    Enables a disabled account before the password is set.

    .PARAMETER ForceChangePasswordNextSignIn
    Makes the user choose their own password at the next sign-in.

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
            "EnableUserIfNeeded": {
                "DisplayName": "Enable the account if disabled?"
            },
            "ForceChangePasswordNextSignIn": {
                "DisplayName": "Require a new password at next sign-in?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.1"
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
