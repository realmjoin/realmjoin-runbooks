<#
  .SYNOPSIS
  Remove all App- and Mobilephone auth methods for a user.

  .DESCRIPTION
  Remove all App- and Mobilephone auth methods for a user. User can re-enroll MFA.

  .NOTES
  Permissions needed:
  - UserAuthenticationMethod.ReadWrite.All

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
    [String]$UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

"## Trying to remove all MFA methods for user '$UserName'"

# "Find phone auth. methods for user $UserName"
$phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta

# "Find Authenticator App auth methods for user $UserName"
$appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta

# "Find Classic OATH App auth methods for user $UserName"
$OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods" -Beta

# "Find FIDO2 auth methods for user $UserName"
$fido2AMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods" -Beta

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs) -or ($OATHAMs) -or ($fido2AMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        "## Trying to remove mobile phone method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
        }
    }

    $OATHAMs | ForEach-Object {
        "## Trying to remove OATH method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
        }
    }

    $fido2AMs | ForEach-Object {
        "## Trying to remove FIDO2 method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
        }
    }

    $appAMs | ForEach-Object {
        "## Trying to remove app method, id: $($_.id)" 
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods/$($_.id)" -Method Delete -Beta | Out-Null
        }
        catch {
            "## Failed or not found. "
        }
    }

    "## Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    # "Find phone auth. methods for user $UserName"
    $phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta

    # "Find Authenticator App auth methods for user $UserName"
    $appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta

    # "Find Classic OATH App auth methods for user $UserName"
    $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/softwareOathMethods" -Beta

    # "Find FIDO2 auth methods for user $UserName"
    $fido2AMs = $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/fido2Methods" -Beta
    
}

if ($count -le 3) {
    "## All App, OATH, FIDO2 and Mobile Phone MFA methods for '$UserName' successfully removed."
}
else {
    "## Could not remove all MFA methods for '$UserName'. Please review."
}