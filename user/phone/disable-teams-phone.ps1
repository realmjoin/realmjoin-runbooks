<#
  .SYNOPSIS
  Microsoft Teams telephony offboarding

  .DESCRIPTION
  Remove the phone number and specific policies from a teams-enabled user.
  Note: A Microsoft Teams service account must be available and stored - details can be found in the runbook.
  
  .NOTES
  Permissions: 
   The MicrosoftTeams PS module requires to use a "real user account" for some operations.
   This user will need the Azure AD roles: 
    - "Teams Administrator"
    - "Skype for Business Administrator"
   If you want to use this runbook, you will have to
   - Create an ADM-User object, e.g. "ADM-ServiceUser.TeamsAutomation"
   - Assign a password to the user
   - Set the password to never expire (or track the password changes accordingly)
   - Disable MFA for this user / make sure conditional access is not blocking the user
   - Add the following AzureAD roles permanently to the user:
     "Teams Administrator"
     "Skype for Business Administrator"
   - Create a credentials object in the Azure Automation Account you use for the RealmJoin Runbooks, call the credentials "teamsautomation".
   - Store the credentials (username and password) in "teamsautomation".
   This is not a recommended situation and will be fixed as soon as a technical solution is known. 

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "CallerName": {
            "Hide": true
        }
    }
}
#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, @{ModuleName = "MicrosoftTeams"; ModuleVersion = "3.1.0" }
param(
    [Parameter(Mandatory = $true)]
    # User which should be cleared
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
##             Connect Part
##          
########################################################
# Needs a Microsoft Teams Connection First!

Write-Output "Connection - Connect to Microsoft Teams (PowerShell)"

#Needs to be replaced to an RealmJoin Setting!!!
$CredAutomation = Get-AutomationPSCredential -Name 'teamsautomation'
Connect-MicrosoftTeams -Credential $CredAutomation

# Check if Teams connection is active
try {
    $Test = Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    try {        
        Start-Sleep -Seconds 5
        Write-Output "2nd try after five seconds"
        $Test = Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {        
        Write-Warning "Teams PowerShell session could not be established. Stopping script!" 
        Exit
    }
}
 
########################################################
##             Get StatusQuo
##          
########################################################

Write-Output "Getting StatusQuo for $UserName"
$StatusQuo = Get-CsOnlineUser $UserName

$CurrentLineUri = $StatusQuo.LineURI -replace("tel:","")

if ($StatusQuo.OnlineVoiceRoutingPolicy -like "") {
    $CurrentOnlineVoiceRoutingPolicy = "Global"
}else {
    $CurrentOnlineVoiceRoutingPolicy = $StatusQuo.OnlineVoiceRoutingPolicy
}

if ($StatusQuo.CallingPolicy -like "") {
    $CurrentCallingPolicy = "Global"
}else {
    $CurrentCallingPolicy = $StatusQuo.CallingPolicy
}

if ($StatusQuo.DialPlan -like "") {
    $CurrentDialPlan = "Global"
}else {
    $CurrentDialPlan = $StatusQuo.DialPlan
}

if ($StatusQuo.TenantDialPlan -like "") {
    $CurrentTenantDialPlan = "Global"
}else {
    $CurrentTenantDialPlan = $StatusQuo.TenantDialPlan
}

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

Write-Output "Current LineUri: $CurrentLineUri"
Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"

########################################################
##             Remove Number from User
##          
########################################################

Write-Output "Start disable process:"
Write-Output "Remove LineUri"
try {
    Remove-CsPhoneNumberAssignment -Identity $UserName -RemoveAll
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the LineUri for $UPN could not be completed!"
    Write-Error "Error Message: $message"
    throw "Teams - Error: Removing the LineUri for $UPN could not be completed!"
}

Write-Output "Remove OnlineVoiceRoutingPolicy (Set to ""global"")"
try {
    Grant-CsOnlineVoiceRoutingPolicy -Identity $UserName -PolicyName ""
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the of OnlineVoiceRoutingPolicy for $UPN could not be completed!"
    Write-Error "Error Message: $message"
    throw "Teams - Error: Removing the OnlineVoiceRoutingPolicy for $UPN could not be completed!"
}

Write-Output "Remove (Tenant)DialPlan (Set to ""global"")"
try {
    Grant-CsTenantDialPlan -Identity $UserName -PolicyName ""
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the of TenantDialPlan for $UPN could not be completed!"
    Write-Error "Error Message: $message"
    throw "Teams - Error: Removing the of TenantDialPlan for $UPN could not be completed!"
}

Write-Output "Done!"