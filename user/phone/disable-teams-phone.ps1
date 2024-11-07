<#
  .SYNOPSIS
  Microsoft Teams telephony offboarding

  .DESCRIPTION
  Remove the phone number and specific policies from a teams-enabled user.
  
  .NOTES
  Permissions: 
  The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
  If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
  However, it should be switched to Managed Identity as soon as possible!

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.6.0" }

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

try {
    $CredAutomation = Get-AutomationPSCredential -Name 'teamsautomation'
}
catch {
    Write-Output "Connection - No automation credentials "teamsautomation" stored. Try newer managed identity approach now"
}

if ($CredAutomation -notlike "") {
    $VerbosePreference = "SilentlyContinue"
    Connect-MicrosoftTeams -Credential $CredAutomation 
    $VerbosePreference = "Continue"
}else {
    Write-Output "Connection - Connect as RealmJoin managed identity"
    $VerbosePreference = "SilentlyContinue"
    Connect-MicrosoftTeams -Identity -ErrorAction Stop
    $VerbosePreference = "Continue"
}

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

# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

########################################################
##             Get StatusQuo
##          
########################################################

# Get StatusQuo
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Getting StatusQuo for user with submitted ID:  $UserName"
try {
    $StatusQuo = Get-CsOnlineUser $UserName
}
catch {
    $message = $_
    if ($message -like "userId was not found") {
        Write-Error "User information could not be retrieved because the UserID was not found. This is usually the case if the user is not licensed for Microsoft Teams or the replication of the license in the Microsoft backend has not yet been completed. Please check the license and run it again after a minimum replication time of one hour."
    }else {
        Write-Error "$message"
    }
}

$UPN = $StatusQuo.UserPrincipalName
Write-Output "UPN from user: $UPN"

$CurrentLineUri = $StatusQuo.LineURI -replace("tel:","")

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") {
    $CurrentLineUri = "none"
}

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

if ($StatusQuo.TeamsIPPhonePolicy -like "") {
    $CurrentTeamsIPPhonePolicy = "Global"
}else {
    $CurrentTeamsIPPhonePolicy = $StatusQuo.TeamsIPPhonePolicy
}

if ($StatusQuo.OnlineVoicemailPolicy -like "") {
    $CurrentOnlineVoicemailPolicy = "Global"
}else {
    $CurrentOnlineVoicemailPolicy = $StatusQuo.OnlineVoicemailPolicy
}

if ($StatusQuo.TeamsMeetingPolicy -like "") {
    $CurrentTeamsMeetingPolicy = "Global"
}else {
    $CurrentTeamsMeetingPolicy = $StatusQuo.TeamsMeetingPolicy
}

if ($StatusQuo.TeamsMeetingBroadcastPolicy -like "") {
    $CurrentTeamsMeetingBroadcastPolicy = "Global"
}else {
    $CurrentTeamsMeetingBroadcastPolicy = $StatusQuo.TeamsMeetingBroadcastPolicy
}

Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"
Write-Output "Current TeamsIPPhonePolicy: $CurrentTeamsIPPhonePolicy"
Write-Output "Current OnlineVoicemailPolicy: $CurrentOnlineVoicemailPolicy"
Write-Output "Current TeamsMeetingPolicy: $CurrentTeamsMeetingPolicy"
Write-Output "Current TeamsMeetingBroadcastPolicy (Live Event Policy): $CurrentTeamsMeetingBroadcastPolicy"

########################################################
##             Remove Number from User
##          
########################################################

Write-Output ""
Write-Output "Start disable process:"
Write-Output "---------------------"
Write-Output "Remove LineUri"
try {
    Remove-CsPhoneNumberAssignment -Identity $UserName -RemoveAll
}
catch {
    $message = $_
    Write-Error -Message "Teams - Error: Removing the LineUri for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the LineUri for $UPN could not be completed!"
}

Write-Output "Remove OnlineVoiceRoutingPolicy (Set to ""global"")"
try {
    Grant-CsOnlineVoiceRoutingPolicy -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error -Message "Teams - Error: Removing the of OnlineVoiceRoutingPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the OnlineVoiceRoutingPolicy for $UPN could not be completed!"
}

Write-Output "Remove (Tenant)DialPlan (Set to ""global"")"
try {
    Grant-CsTenantDialPlan -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error -Message "Teams - Error: Removing the of TenantDialPlan for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the of TenantDialPlan for $UPN could not be completed!"
}

Write-Output "Remove Teams IP-Phone Policy (Set to ""global"")"
try {
    Grant-CsTeamsIPPhonePolicy -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error -Message "Teams - Error: Removing the of Teams IP-Phone Policy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the of Teams IP-Phone Policy for $UPN could not be completed!"
}

Write-Output "Remove Teams Online Voicemail Policy (Set to ""global"")"
try {
    Grant-CsOnlineVoicemailPolicy -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error -Message "Teams - Error: Removing the of OnlineVoicemailPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the of OnlineVoicemailPolicy for $UPN could not be completed!"
}

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null