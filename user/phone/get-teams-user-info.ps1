<#
  .SYNOPSIS
  Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.
  
  .DESCRIPTION
  Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.
  
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
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
##             function declaration
##          
########################################################

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
        $Test = Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error -Message "Teams PowerShell session could not be established. Stopping script!" -ErrorAction Continue
        throw "Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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
    $StatusQuo_Forward = Get-CsUserCallingSettings -Identity $UserName
    $StatusQuo_PhoneNumber = Get-CsPhoneNumberAssignment -AssignedPstnTargetId $UserName
}
catch {
    $message = $_
    if ($message -like "userId was not found") {
        Write-Error "User information could not be retrieved because the UserID was not found. This is usually the case if the user is not licensed for Microsoft Teams or the replication of the license in the Microsoft backend has not yet been completed. Please check the license and run it again after a minimum replication time of one hour."
    }else {
        Write-Error "$message"
    }
}

try {
    
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

if ($StatusQuo_PhoneNumber.NumberType -like "") {
    $CurrentNumberType = "none"
}else {
    $CurrentNumberType = $StatusQuo_PhoneNumber.NumberType
}

Write-Output ""
Write-Output "Policies:"
Write-Output "---------------------"
Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"
Write-Output "Current TeamsIPPhonePolicy: $CurrentTeamsIPPhonePolicy"
Write-Output "Current OnlineVoicemailPolicy: $CurrentOnlineVoicemailPolicy"
Write-Output "Current TeamsMeetingPolicy: $CurrentTeamsMeetingPolicy"
Write-Output "Current TeamsMeetingBroadcastPolicy (Live Event Policy): $CurrentTeamsMeetingBroadcastPolicy"
Write-Output ""
Write-Output "Voice:"
Write-Output "---------------------"
Write-Output "Current LineUri: $CurrentLineUri"
Write-Output "Current Number Type: $CurrentNumberType"
Write-Output ""
Write-Output "Current immediate call forwarding:"
if (($StatusQuo_Forward.IsForwardingEnabled -eq $true) -and ($StatusQuo_Forward.ForwardingType -like "Immediate")) {
    Write-Output "Immediate call forward is active"
    if ($StatusQuo_Forward.ForwardingTargetType -like "SingleTarget" ) {
        Write-Output "Target: $($StatusQuo_Forward.ForwardingTarget )"
    }elseif ($StatusQuo_Forward.ForwardingTargetType -like "Voicemail") {
        Write-Output "Target: Voicemail"
    }elseif ($StatusQuo_Forward.ForwardingTargetType -like "Group") {
        Write-Output "Target: Call group"
        Write-Output "Group membership details:"
        Write-Output "$($StatusQuo_Forward.GroupMembershipDetails)"
    }elseif ($StatusQuo_Forward.ForwardingTargetType -like "MyDelegates") {
        Write-Output "Target: Delegates"
        Write-Output "Current delegates and delegate Settings:"
        Write-Output "$($StatusQuo_Forward.Delegates)"
    }
}else {
    Write-Output "No immediate call forwarding is active"
}

Write-Output ""
Write-Output "Enterprise Voice (for PSTN) - License check:"
Write-Output "---------------------"

$AssignedPlan = $StatusQuo.AssignedPlan

if ($AssignedPlan.Capability -like "MCOSTANDARD" -or $AssignedPlan.Capability -like "MCOEV" -or $AssignedPlan.Capability -like "MCOEV-*") {
    Write-Output "License check - Microsoft O365 Phone Standard is generally assigned to this user"

    #Validation whether license is already assigned long enough
    $Now = get-date

    $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOSTANDARD").AssignedTimestamp

    if ($LicenseTimeStamp -like "") {
        $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOEV*").AssignedTimestamp
    }
    if ($LicenseTimeStamp -notlike "") {
        try {
            if ($LicenseTimeStamp.AddHours(1) -lt $Now ) {
                Write-Output "The license has already been assigned to the user for more than one hour. Date/time of license assignment: $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss"))"
                if (($LicenseTimeStamp.AddHours(24) -gt $Now)) {
                    Write-Output "Note: In some cases, this may not yet be sufficient. It can take up to 24h until the license replication in the backend is completed!"
                }
                
            }else {
                Write-Output ""
                Write-Warning "Error:"
                Write-Warning "The user license (MCOEV - Microsoft O365 Phone Standard) should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. "
                Write-Warning "The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Provisions regarding telephony not before: ($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss"))"
            }
        }
        catch {
            Write-Warning "Warning: The time of license assignment could not be verified!"
        }
    }else {
        Write-Warning "Warning: The time of license assignment could not be verified!"
    }

}else {
    Write-Output ""
    Write-Output "License check - Microsoft O365 Phone Standard is NOT assigned to this user"


}

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null