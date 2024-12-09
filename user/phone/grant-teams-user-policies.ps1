<#
  .SYNOPSIS
  Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. 
  
  .DESCRIPTION
  Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. 
  If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
  
  .NOTES
  Permissions: 
  The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
  If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
  However, it should be switched to Managed Identity as soon as possible!

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "OnlineVoiceRoutingPolicy": {
            "DisplayName": "Microsoft Teams Online Voice Routing Policy Name"
        },
        "TenantDialPlan": {
            "DisplayName": "Microsoft Teams DialPlan Name"
        },
        "TeamsCallingPolicy": {
            "DisplayName": "Microsoft Teams Calling Policy Name"
        },
        "OnlineVoicemailPolicy": {
            "DisplayName": "Microsoft Teams Online Voicemail Policy Name"
        },
        "TeamsIPPhonePolicy": {
            "DisplayName": "Microsoft Teams IP-Phone Policy Name (a.o. for Common Area Phone Users)"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,
    [String] $OnlineVoiceRoutingPolicy,
    [String] $TenantDialPlan,
    [String] $TeamsCallingPolicy,
    [String] $TeamsIPPhonePolicy,
    [String] $OnlineVoicemailPolicy,
    [String] $TeamsMeetingPolicy,
    [String] $TeamsMeetingBroadcastPolicy,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
}
else {
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
        $Test = Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {        
        Write-Error -Message "Teams PowerShell session could not be established. Stopping script!" -ErrorAction Continue
        throw "Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

########################################################
##             StatusQuo & Preflight-Check Part
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
    }
    else {
        Write-Error "$message"
    }
}

$UPN = $StatusQuo.UserPrincipalName
Write-Output "UPN from user: $UPN"

if ($StatusQuo.OnlineVoiceRoutingPolicy -like "") {
    $CurrentOnlineVoiceRoutingPolicy = "Global"
}
else {
    $CurrentOnlineVoiceRoutingPolicy = $StatusQuo.OnlineVoiceRoutingPolicy
}

if ($StatusQuo.CallingPolicy -like "") {
    $CurrentCallingPolicy = "Global"
}
else {
    $CurrentCallingPolicy = $StatusQuo.CallingPolicy
}

if ($StatusQuo.DialPlan -like "") {
    $CurrentDialPlan = "Global"
}
else {
    $CurrentDialPlan = $StatusQuo.DialPlan
}

if ($StatusQuo.TenantDialPlan -like "") {
    $CurrentTenantDialPlan = "Global"
}
else {
    $CurrentTenantDialPlan = $StatusQuo.TenantDialPlan
}

if ($StatusQuo.TeamsIPPhonePolicy -like "") {
    $CurrentTeamsIPPhonePolicy = "Global"
}
else {
    $CurrentTeamsIPPhonePolicy = $StatusQuo.TeamsIPPhonePolicy
}

if ($StatusQuo.OnlineVoicemailPolicy -like "") {
    $CurrentOnlineVoicemailPolicy = "Global"
}
else {
    $CurrentOnlineVoicemailPolicy = $StatusQuo.OnlineVoicemailPolicy
}

if ($StatusQuo.TeamsMeetingPolicy -like "") {
    $CurrentTeamsMeetingPolicy = "Global"
}
else {
    $CurrentTeamsMeetingPolicy = $StatusQuo.TeamsMeetingPolicy
}

if ($StatusQuo.TeamsMeetingBroadcastPolicy -like "") {
    $CurrentTeamsMeetingBroadcastPolicy = "Global"
}
else {
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

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Init $TMP for "Global (Org Wide Default) Case"
$TMP = $null

# Check if specified Online Voice Routing Policy exists, if submitted
if ($OnlineVoiceRoutingPolicy -notlike "") {
    try {
        if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Online Voice Routing Policy exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsOnlineVoiceRoutingPolicy $OnlineVoiceRoutingPolicy -ErrorAction Stop
            Write-Output "The specified Online Voice Routing Policy exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Online Voice Routing Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $OnlineVoiceRoutingPolicy" -ErrorAction Continue
        throw "The specified Online Voice Routing Policy could not be found in the tenant! Please check the specified policy! Submitted policy name: $OnlineVoiceRoutingPolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}

# Check if specified Tenant Dial Plan exists, if submitted
if ($TenantDialPlan -notlike "") {
    try {
        if ($TenantDialPlan -like "Global (Org Wide Default)") {
            Write-Output "The specified Tenant Dial Plan exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsTenantDialPlan $TenantDialPlan -ErrorAction Stop
            Write-Output "The specified Tenant Dial Plan exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Tenant Dial Plan could not be found in the tenant. Please check the specified policy! Submitted policy name: $TenantDialPlan" -ErrorAction Continue
        throw "The specified Tenant Dial Plan could not be found in the tenant! Please check the specified policy! Submitted policy name: $TenantDialPlan"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}


# Check if specified Teams Calling Policy exists, if submitted
if ($TeamsCallingPolicy -notlike "") {
    try {
        if ($TeamsCallingPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams Calling Policy exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsTeamsCallingPolicy $TeamsCallingPolicy -ErrorAction Stop
            Write-Output "The specified Teams Calling Policy exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Teams Calling Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $TeamsCallingPolicy" -ErrorAction Continue
        throw "The specified Teams Calling Policy could not be found in the tenant! Please check the specified policy! Submitted policy name: $TeamsCallingPolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}

# Check if specified Teams IP-Phone Policy exists, if submitted
if ($TeamsIPPhonePolicy -notlike "") {
    try {
        if ($TeamsIPPhonePolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams IP-Phone Policy exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsTeamsIPPhonePolicy $TeamsIPPhonePolicy -ErrorAction Stop
            Write-Output "The specified Teams IP-Phone Policy exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Teams IP-Phone Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $TeamsIPPhonePolicy" -ErrorAction Continue
        throw "The specified Teams IP-Phone Policy could not be found in the tenant! Please check the specified policy! Submitted policy name: $TeamsIPPhonePolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}

# Check if specified Teams IP-Phone Policy exists, if submitted
if ($OnlineVoicemailPolicy -notlike "") {
    try {
        if ($OnlineVoicemailPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams Online Voicemail Policy exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsOnlineVoicemailPolicy $OnlineVoicemailPolicy -ErrorAction Stop
            Write-Output "The specified Teams Online Voicemail Policy exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Teams Online Voicemail Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $OnlineVoicemailPolicy" -ErrorAction Continue
        throw "The specified Teams Online Voicemail Policy could not be found in the tenant! Please check the specified policy! Submitted policy name: $OnlineVoicemailPolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}

# Check if specified Teams Meeting Policy exists, if submitted
if ($TeamsMeetingPolicy -notlike "") {
    try {
        if ($TeamsMeetingPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams Meeting Policy exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsTeamsMeetingPolicy $TeamsMeetingPolicy -ErrorAction Stop
            Write-Output "The specified Teams Meeting Policy exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Teams Meeting Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $TeamsMeetingPolicy" -ErrorAction Continue
        throw "The specified Teams Meeting Policy could not be found in the tenant! Please check the specified policy! Submitted policy name: $TeamsMeetingPolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}


# Check if specified Teams Meeting Broadcast Policy (Live Event Policy) exists, if submitted
if ($TeamsMeetingBroadcastPolicy -notlike "") {
    try {
        if ($TeamsMeetingBroadcastPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams Meeting Broadcast Policy (Live Event Policy) exists - (Global (Org Wide Default))"
        }
        else {
            $TMP = Get-CsTeamsMeetingBroadcastPolicy $TeamsMeetingBroadcastPolicy -ErrorAction Stop
            Write-Output "The specified Teams Meeting Broadcast Policy (Live Event Policy) exists"
        }
    }
    catch {
        Write-Error -Message  "Teams - Error: The specified Teams Meeting Broadcast Policy (Live Event Policy) could not be found in the tenant. Please check the specified policy! Submitted policy name: $TeamsMeetingBroadcastPolicy" -ErrorAction Continue
        throw "The specified Teams Meeting Broadcast Policy (Live Event Policy) could not be found in the tenant! Please check the specified policy! Submitted policy name: $TeamsMeetingBroadcastPolicy"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}


########################################################
##             Main Part
##          
########################################################

Write-Output ""
Write-Output "Grant process"
Write-Output "---------------------"

# Grant OnlineVoiceRoutingPolicy, if submitted
if ($OnlineVoiceRoutingPolicy -notlike "") {
    Write-Output "OnlineVoiceRoutingPolicy: $OnlineVoiceRoutingPolicy"
    try {
        if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
            Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $OnlineVoiceRoutingPolicy -ErrorAction Stop   
        }
    }
    catch {
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed!"
    }
}

# Grant TenantDialPlan, if submitted
if ($TenantDialPlan -notlike "") {
    Write-Output "TenantDialPlan: $TenantDialPlan"
    try {
        if ($TenantDialPlan -like "Global (Org Wide Default)") {
            Grant-CsTenantDialPlan -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsTenantDialPlan -Identity $UPN -PolicyName $TenantDialPlan -ErrorAction Stop  
        }
    }
    catch {
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed!"
    }
}

# Grant TeamsCallingPolicy, if submitted
if ($TeamsCallingPolicy -notlike "") {
    Write-Output "CallingPolicy: $TeamsCallingPolicy"
    try {
        if ($TeamsCallingPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $TeamsCallingPolicy -ErrorAction Stop  
        }  
    }
    catch {        
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed!"
    }
}

# Grant TeamsIPPhonePolicy, if submitted
if ($TeamsIPPhonePolicy -notlike "") {
    Write-Output "TeamsIPPhonePolicy: $TeamsIPPhonePolicy"
    try {
        if ($TeamsIPPhonePolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsIPPhonePolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsTeamsIPPhonePolicy -Identity $UPN -PolicyName $TeamsIPPhonePolicy -ErrorAction Stop  
        }  
    }
    catch {        
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of TeamsIPPhonePolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of TeamsIPPhonePolicy for $UPN could not be completed!"
    }
}

# Grant OnlineVoicemailPolicy, if submitted
if ($OnlineVoicemailPolicy -notlike "") {
    Write-Output "OnlineVoicemailPolicy: $OnlineVoicemailPolicy"
    try {
        if ($OnlineVoicemailPolicy -like "Global (Org Wide Default)") {
            Grant-CsOnlineVoicemailPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsOnlineVoicemailPolicy -Identity $UPN -PolicyName $OnlineVoicemailPolicy -ErrorAction Stop  
        }  
    }
    catch {        
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of OnlineVoicemailPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of OnlineVoicemailPolicy for $UPN could not be completed!"
    }
}

# Grant TeamsMeetingPolicy, if submitted
if ($TeamsMeetingPolicy -notlike "") {
    Write-Output "TeamsMeetingPolicy: $TeamsMeetingPolicy"
    try {
        if ($TeamsMeetingPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsMeetingPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsTeamsMeetingPolicy -Identity $UPN -PolicyName $TeamsMeetingPolicy -ErrorAction Stop
        }    
    }
    catch {
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of TeamsMeetingPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of TeamsMeetingPolicy for $UPN could not be completed!"
    }
}

# Grant TeamsMeetingBroadcastPolicy, if submitted
if ($TeamsMeetingBroadcastPolicy -notlike "") {
    Write-Output "TeamsMeetingBroadcastPolicy: $TeamsMeetingBroadcastPolicy"
    try {
        if ($TeamsMeetingBroadcastPolicy -like "Global (Org Wide Default)") {
            Grant-CsTeamsMeetingBroadcastPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
        }
        else {
            Grant-CsTeamsMeetingBroadcastPolicy -Identity $UPN -PolicyName $TeamsMeetingBroadcastPolicy -ErrorAction Stop 
        }     
    }
    catch {
        $message = $_
        Write-Error -Message "Teams - Error: The assignment of TeamsMeetingBroadcastPolicy for $UPN could not be completed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment of TeamsMeetingBroadcastPolicy for $UPN could not be completed!"
    }
}

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null