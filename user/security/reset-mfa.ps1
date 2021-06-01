# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules MEMPSToolkit, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName
)

#region module check
function Test-ModulePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$neededModule
    )
    if (-not (Get-Module -ListAvailable $neededModule)) {
        throw ($neededModule + " is not available and can not be installed automatically. Please check.")
    }
    else {
        Import-Module $neededModule
        # "Module " + $neededModule + " is available."
    }
}

Test-ModulePresent "MEMPSToolkit"
Test-ModulePresent "RealmJoin.RunbookHelper"
#endregion

#region Authentication
# "Connect to Graph API..."
Connect-RjRbGraph
#endregion

# "Find mobile phone auth. methods for user $UserName"
$phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $Global:RjRbGraphAuthHeaders
if ($phoneAMs) {
   "Mobile phone methods found."
} else {
   "No mobile phone methods found."
}

# "Find Authenticator App auth methods for user $UserName"
$appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $Global:RjRbGraphAuthHeaders
if ($appAMs) {
    "Apps methods found."
} else {
    "No apps methods found."
}

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        "trying to remove mobile phone method, id: $($_.id)"
        try {
            Remove-AADUserPhoneAuthMethod -userID $UserName -authId $_.id -authToken $Global:RjRbGraphAuthHeaders
        } catch {
            "Failed or not found. "
        }
    }

    $appAMs | ForEach-Object {
        "trying to remove app method, id: $($_.id)" 
        try {
            Remove-AADUserMSAuthenticatorMethod -userID $UserName -authId $_.id -authToken $Global:RjRbGraphAuthHeaders
        } catch {
            "Failed or not found. "
        }
    }

    "Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    # "Find mobile phone auth. methods for user $UserName "
    $phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $Global:RjRbGraphAuthHeaders
    if ($phoneAMs) {
        "Mobile phone methods found."
    } else {
        "No mobile phone methods found."
    }
    
    # "Find Authenticator App auth methods for user $UserNamer"
    $appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $Global:RjRbGraphAuthHeaders
    if ($appAMs) {
        "Apps methods found."
    } else {
        "No apps methods found."
    }
    
}

if ($count -le 3) {
    "All App and Mobile Phone MFA methods for $UserName successfully removed."
} else {
    "Could not remove all App and Mobile Phone MFA methods for $UserName. Please review."
}