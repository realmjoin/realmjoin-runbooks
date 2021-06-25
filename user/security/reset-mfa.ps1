# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

<#
  .SYNOPSIS
  Remove all App- and Mobilephone auth methods for a user.

  .DESCRIPTION
  Remove all App- and Mobilephone auth methods for a user. User can re-enroll MFA.

#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String]$UserName
)

Connect-RjRbGraph

# "Find phone auth. methods for user $UserName"
$phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta

# "Find Authenticator App auth methods for user $UserName"
$appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        "trying to remove mobile phone method, id: $($_.id)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($_.id)" -Method Delete -Beta | Out-Null
        } catch {
            "Failed or not found. "
        }
    }

    $appAMs | ForEach-Object {
        "trying to remove app method, id: $($_.id)" 
        try {
            Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods/$($_.id)" -Method Delete -Beta | Out-Null
        } catch {
            "Failed or not found. "
        }
    }

    "Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    # "Find phone auth. methods for user $UserName "
    $phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta
    
    # "Find Authenticator App auth methods for user $UserNamer"
    $appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/microsoftAuthenticatorMethods" -Beta
    
}

if ($count -le 3) {
    "All App and Mobile Phone MFA methods for $UserName successfully removed."
} else {
    "Could not remove all App and Mobile Phone MFA methods for $UserName. Please review."
}