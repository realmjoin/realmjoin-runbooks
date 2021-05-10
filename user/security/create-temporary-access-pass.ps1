# This runbook will create an AAD temporary access pass for a user. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    # How long (starting immediately) is the pass valid?
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [int] $lifetimeInMinutes = 240,
    # Is this a one-time pass (prefered); will be usable multiple times otherwise
    [bool] $oneTimeUseOnly = $true
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

Write-Output ("Making sure, no old temp. access passes exist for " + $UserName)
Remove-AadUserTemporaryAccessPass -authToken $token -userID $UserName

Write-Output ("Creating new temp. access pass")
$pass = New-AadUserTemporaryAccessPass -authToken $token -userID $UserName -oneTimeUse $oneTimeUseOnly -lifetimeInMinutes $lifetimeInMinutes

if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
    Write-Output ("Beware: The use of Temporary access passes seems to be disabled for this user.")
}

Write-Output ("New Temporary access pass for " + $UserName + " with a lifetime of " + $lifetimeInMinutes +" minutes has been created: " + $pass.temporaryAccessPass)
