<#
  .SYNOPSIS
  Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. 
  
  .DESCRIPTION
  Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
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
        "OnlineVoiceRoutingPolicy": {
            "DisplayName": "Microsoft Teams OnlineVoiceRoutingPolicy Name"
        },
        "TenantDialPlan": {
            "DisplayName": "Microsoft Teams DialPlan Name"
        },
        "TeamsCallingPolicy": {
            "DisplayName": "Microsoft Teams CallingPolicy Name"
        },
        "TeamsMeetingPolicy": {
            "DisplayName": "Microsoft Teams Meeting Policy Name"
        },
        "TeamsMeetingBroadcastPolicy": {
            "DisplayName": "Microsoft Teams Meeting Broadcast Policy Name (Live Event Policy)"
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>


#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, @{ModuleName = "MicrosoftTeams"; ModuleVersion = "3.1.0" }
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,
    [String] $OnlineVoiceRoutingPolicy,
    [String] $TenantDialPlan,
    [String] $TeamsCallingPolicy,
    [String] $TeamsMeetingPolicy,
    [String] $TeamsMeetingBroadcastPolicy,

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

$CredAutomation = Get-AutomationPSCredential -Name 'teamsautomation'
Connect-MicrosoftTeams -Credential $CredAutomation

# Check if Teams connection is active
try {
    $Test = Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    try {
        Start-Sleep -Seconds 5
        $Test = Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {        
        Write-Error "Teams PowerShell session could not be established. Stopping script!"
        throw "Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

########################################################
##             StatusQuo & Preflight-Check Part
##          
########################################################

# Get StatusQuo
Write-Output "Getting StatusQuo for user with ID:  $UserName"
$StatusQuo = Get-CsOnlineUser $UserName

$UPN = $StatusQuo.UserPrincipalName
Write-Output "UPN from user: $UPN"

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
Write-Output "Current TeamsMeetingPolicy: $CurrentTeamsMeetingPolicy"
Write-Output "Current TeamsMeetingBroadcastPolicy (Live Event Policy): $CurrentTeamsMeetingBroadcastPolicy"


########################################################
##             Main Part
##          
########################################################

Write-Output "Set process"

# Set OnlineVoiceRoutingPolicy if defined
if ($OnlineVoiceRoutingPolicy -notlike "") {
    Write-Output "OnlineVoiceRoutingPolicy: $OnlineVoiceRoutingPolicy"
    try {
        if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
            Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $null #reset to default
        }else {
            Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $OnlineVoiceRoutingPolicy   
        }
    }
    catch {
        $message = $_
        Write-Error "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed!"
        Write-Error "Error Message: $message"
        throw "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed!"
    }
}

# Set TenantDialPlan if defined
if ($TenantDialPlan -notlike "") {
    Write-Output "TenantDialPlan: $TenantDialPlan"
    try {
        if ($TenantDialPlan -like "Global (Org Wide Default)") {
            Grant-CsTenantDialPlan -Identity $UPN -PolicyName $null #reset to default
        }else {
            Grant-CsTenantDialPlan -Identity $UPN -PolicyName $TenantDialPlan  
        }
    }
    catch {
        $message = $_
        Write-Error "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed!"
        Write-Error "Error Message: $message"
        throw "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed!"
    }
}

# Set TeamsCallingPolicy if defined
if ($TeamsCallingPolicy -notlike "") {
    Write-Output "CallingPolicy: $TeamsCallingPolicy"
    try {
        if ($TeamsCallingPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $null #reset to default
        }else {
            Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $TeamsCallingPolicy  
        }  
    }
    catch {        
        $message = $_
        Write-Error "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed!"
        Write-Error "Error Message: $message"
        throw "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed!"
    }
}

# Set TeamsMeetingPolicy if defined
if ($TeamsMeetingPolicy -notlike "") {
    Write-Output "TeamsMeetingPolicy: $TeamsMeetingPolicy"
    try {
        if ($TeamsMeetingPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsMeetingPolicy -Identity $UPN -PolicyName $null #reset to default
        }else {
            Grant-CsTeamsMeetingPolicy -Identity $UPN -PolicyName $TeamsMeetingPolicy
        }    
    }
    catch {
        $message = $_
        Write-Error "Teams - Error: The assignment of TeamsMeetingPolicy for $UPN could not be completed!"
        Write-Error "Error Message: $message"
        throw "Teams - Error: The assignment of TeamsMeetingPolicy for $UPN could not be completed!"
    }
}

# Set TeamsMeetingBroadcastPolicy if defined
if ($TeamsMeetingBroadcastPolicy -notlike "") {
    Write-Output "TeamsMeetingBroadcastPolicy: $TeamsMeetingBroadcastPolicy"
    try {
        if ($TeamsMeetingBroadcastPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsMeetingBroadcastPolicy -Identity $UPN -PolicyName $null #reset to default
        }else {
            Grant-CsTeamsMeetingBroadcastPolicy -Identity $UPN -PolicyName $TeamsMeetingBroadcastPolicy 
        }     
    }
    catch {
        $message = $_
        Write-Error "Teams - Error: The assignment of TeamsMeetingBroadcastPolicy for $UPN could not be completed!"
        Write-Error "Error Message: $message"
        throw "Teams - Error: The assignment of TeamsMeetingBroadcastPolicy for $UPN could not be completed!"
    }
}

Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null