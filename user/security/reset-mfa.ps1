# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
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