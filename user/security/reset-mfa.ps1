# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID
)

#region module check
$neededModule = "MEMPSToolkit"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName

write-output ("Find mobile phone auth. methods for user " + $UserName) 
$phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $token
if ($phoneAMs) {
    write-output "Mobile phone methods found."
} else {
    write-output "No mobile phone methods found."
}

write-output ("Find Authenticator App auth methods for user " + $UserName)
$appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $token
if ($appAMs) {
    write-output "Apps methods found."
} else {
    write-output "No apps methods found."
}

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        write-output ("try to remove mobile phone method, id: " + $_.id) 
        try {
            Remove-AADUserPhoneAuthMethod -userID $UserName -authId $_.id -authToken $token
        } catch {
            write-output "Failed or not found. "
        }
    }

    $appAMs | ForEach-Object {
        write-output ("try to remove app method, id: " + $_.id) 
        try {
            Remove-AADUserMSAuthenticatorMethod -userID $UserName -authId $_.id -authToken $token
        } catch {
            write-output "Failed or not found. "
        }
    }

    Write-Output "Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    write-output ("Find mobile phone auth. methods for user " + $UserName) 
    $phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $token
    if ($phoneAMs) {
        write-output "Mobile phone methods found."
    } else {
        write-output "No mobile phone methods found."
    }
    
    write-output ("Find Authenticator App auth methods for user " + $UserName)
    $appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $token
    if ($appAMs) {
        write-output "Apps methods found."
    } else {
        write-output "No apps methods found."
    }
    
}

if ($count -le 3) {
    Write-Output ("All App and Mobile Phone MFA methods for " + $UserName + " successfully removed.")
} else {
    Write-Output ("Could not remove all App and Mobile Phone MFA methods for " + $UserName + ". Please review.")
}