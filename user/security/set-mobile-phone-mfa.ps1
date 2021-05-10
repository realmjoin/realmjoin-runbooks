# This runbook will add or update a user's mobile phone MFA information.
# It will NOT change the default auth method.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Module MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    [String]$phoneNumber
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

#region Authentication
# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

write-output ("Find phone auth. methods for user " + $UserName) 
$phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $token
if ($phoneAMs) {
    write-output "Phone methods found. Will update primary entry."
    $authId = ($phoneAMs | Where-Object {$_.phoneType -eq "mobile"}).id
    Update-AADUserPhoneAuthMethod -authToken $token -userID $UserName -authId $authId -phoneNumber $phoneNumber 
} else {
    write-output "No phone methods found. Will add a new one."
    Add-AADUserPhoneAuthMethod -authToken $token -userID $UserName -phoneNumber $phoneNumber 
}
write-output ("Successfully added mobile phone authentication number " + $phoneNumber + " to user "+ $UserName + ".")