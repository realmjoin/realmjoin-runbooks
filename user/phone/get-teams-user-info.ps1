<#
  .SYNOPSIS
  Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

  .DESCRIPTION
  Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

  .PARAMETER UserName
  The user for whom the status quo should be retrieved. This can be filled in with the user picker in the UI.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "CallerName": {
            "Hide": true
        }
    }
}
#>


#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,

    # CallerName is tracked purely for auditing purposes
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

try {
    $VerbosePreference = "SilentlyContinue"
    $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
    $VerbosePreference = "Continue"
    # Check if Teams connection is active
    Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    try {
        $VerbosePreference = "SilentlyContinue"
        $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
        $VerbosePreference = "Continue"
        # Check if Teams connection is active
        Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

# Add check symbol to variable, wich is compatible with powershell 5.1
$symbol_check = [char]0x2714

#endregion
########################################################
#region     Collect basic information
##
########################################################

# Get StatusQuo
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Getting StatusQuo for user with submitted ID:  $UserName"
try {
    $StatusQuo = Get-CsOnlineUser -Identity $UserName
    $StatusQuo_Forward = Get-CsUserCallingSettings -Identity $UserName
    $StatusQuo_PhoneNumber = Get-CsPhoneNumberAssignment -AssignedPstnTargetId $UserName
    $StatusQuo_Voicemail = Get-CsOnlineVoicemailUserSettings -Identity $UserName
    $StatusQuo_UserPolicyAssignment = Get-CsUserPolicyAssignment -Identity $UserName
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

Write-Output "Get all Microsoft Teams Call Queues"
# WarningPreference temporarily set to "SilentlyContinue" to suppress "ConferenceMode is turned on" warning
$currentWarningPreference = $WarningPreference
$WarningPreference = "SilentlyContinue"
$callQueues = Get-CsCallQueue | Select-Object -Property Name, Agents
$WarningPreference = $currentWarningPreference
Write-Output " - Received Call Queues: $(($callQueues | Measure-Object).Count)"
$CurrentLineUri = $StatusQuo.LineURI -replace ("tel:", "")

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") {
    $CurrentLineUri = "none"
}

#DialPlan
if ($StatusQuo.DialPlan -like "") {
    $CurrentDialPlan = "Global"
}
else {
    $CurrentDialPlan = $StatusQuo.DialPlan
}

#OnlineVoiceRoutingPolicy
$CurrentOnlineVoiceRoutingPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "OnlineVoiceRoutingPolicy").PolicyName
$CurrentOnlineVoiceRoutingPolicy = if ($CurrentOnlineVoiceRoutingPolicy -like "") { "Global" } else { $CurrentOnlineVoiceRoutingPolicy }

#CallingPolicy
$CurrentCallingPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "CallingPolicy").PolicyName
$CurrentCallingPolicy = if ($CurrentCallingPolicy -like "") { "Global" } else { $CurrentCallingPolicy }

#TenantDialPlan
$CurrentTenantDialPlan = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TenantDialPlan").PolicyName
$CurrentTenantDialPlan = if ($CurrentTenantDialPlan -like "") { "Global" } else { $CurrentTenantDialPlan }

#TeamsIPPhonePolicy
$CurrentTeamsIPPhonePolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TeamsIPPhonePolicy").PolicyName
$CurrentTeamsIPPhonePolicy = if ($CurrentTeamsIPPhonePolicy -like "") { "Global" } else { $CurrentTeamsIPPhonePolicy }

#OnlineVoicemailPolicy
$CurrentOnlineVoicemailPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "OnlineVoicemailPolicy").PolicyName
$CurrentOnlineVoicemailPolicy = if ($CurrentOnlineVoicemailPolicy -like "") { "Global" } else { $CurrentOnlineVoicemailPolicy }

#TeamsMeetingPolicy
$CurrentTeamsMeetingPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TeamsMeetingPolicy").PolicyName
$CurrentTeamsMeetingPolicy = if ($CurrentTeamsMeetingPolicy -like "") { "Global" } else { $CurrentTeamsMeetingPolicy }

#TeamsMeetingBroadcastPolicy
$CurrentTeamsMeetingBroadcastPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TeamsMeetingBroadcastPolicy").PolicyName
$CurrentTeamsMeetingBroadcastPolicy = if ($CurrentTeamsMeetingBroadcastPolicy -like "") { "Global" } else { $CurrentTeamsMeetingBroadcastPolicy }

#TeamsVoiceApplicaitonsPolicy
$CurrentTeamsVoiceApplicaitonsPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TeamsVoiceApplicaitonsPolicy").PolicyName
$CurrentTeamsVoiceApplicaitonsPolicy = if ($CurrentTeamsVoiceApplicaitonsPolicy -like "") { "Global" } else { $CurrentTeamsVoiceApplicaitonsPolicy }

#TeamsSharedCallingRoutingPolicy
$CurrentTeamsSharedCallingRoutingPolicy = ($StatusQuo_UserPolicyAssignment | Where-Object PolicyType -eq "TeamsSharedCallingRoutingPolicy").PolicyName
$CurrentTeamsSharedCallingRoutingPolicy = if ($CurrentTeamsSharedCallingRoutingPolicy -like "") { "Global" } else { $CurrentTeamsSharedCallingRoutingPolicy }

if ($StatusQuo_PhoneNumber.NumberType -like "") {
    $CurrentNumberType = "none"
}
else {
    $CurrentNumberType = $StatusQuo_PhoneNumber.NumberType
}

if ($StatusQuo_Voicemail.VoicemailEnabled -eq $true) {
    $CurrentVoicemailStatus = "enabled"
}
else {
    $CurrentVoicemailStatus = "disabled"
}

switch ($StatusQuo_Voicemail.CallAnswerRule) {
    "DeclineCall" {
        $CurrentVoicemailBehavior = "Decline Call"
    }
    "PromptOnly" {
        $CurrentVoicemailBehavior = "Announcement only (call will be terminated after the announcement)"
    }
    "PromptOnlyWithTransfer" {
        $CurrentVoicemailBehavior = "Announcement followed by call transfer"
    }
    "RegularVoicemail" {
        $CurrentVoicemailBehavior = "Regular Voicemail"
    }
    "VoicemailWithTransferOption" {
        $CurrentVoicemailBehavior = "Voicemail With Transfer Option"
    }
    default {
        $CurrentVoicemailBehavior = "Undefined"
    }
}

Write-Output ""
Write-Output "UPN from $($StatusQuo.DisplayName): $UPN"
Write-Output "Usage Location: $($StatusQuo.UsageLocation)"
Write-Output ""
Write-Output "Policies:"
Write-Output "---------------------"
Write-Output "Online Voice Routing Policy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Calling Policy: $CurrentCallingPolicy"
Write-Output "Dial Plan: $CurrentDialPlan"
Write-Output "Tenant Dial Plan: $CurrentTenantDialPlan"
Write-Output "Online Voicemail Policy: $CurrentOnlineVoicemailPolicy"
Write-Output "Teams Voice Applications Policy: $CurrentTeamsVoiceApplicationsPolicy"
Write-Output "Teams Shared Calling Routing Policy: $CurrentTeamsSharedCallingRoutingPolicy"
Write-Output "Teams IP-Phone Policy: $CurrentTeamsIPPhonePolicy"
Write-Output "Teams Meeting Policy: $CurrentTeamsMeetingPolicy"
Write-Output "Teams Live Event Policy (Meeting Broadcast Policy): $CurrentTeamsMeetingBroadcastPolicy"
Write-Output ""
Write-Output "Voice:"
Write-Output "---------------------"
Write-Output "LineUri (phone number): $CurrentLineUri"
Write-Output "Number Type: $CurrentNumberType"
Write-Output ""
Write-Output "Voicemail:"
Write-Output "Status: $CurrentVoicemailStatus"
Write-Output "Operation Mode: $CurrentVoicemailBehavior"
Write-Output ""
Write-Output "Call Forwarding:"
Write-Output "Immediate call forwarding:"
if (($StatusQuo_Forward.IsForwardingEnabled -eq $true) -and ($StatusQuo_Forward.ForwardingType -like "Immediate")) {
    Write-Output "Immediate call forward is active"
    if ($StatusQuo_Forward.ForwardingTargetType -like "SingleTarget" ) {
        Write-Output "Target: $($StatusQuo_Forward.ForwardingTarget )"
    }
    elseif ($StatusQuo_Forward.ForwardingTargetType -like "Voicemail") {
        Write-Output "Target: Voicemail"
    }
    elseif ($StatusQuo_Forward.ForwardingTargetType -like "Group") {
        Write-Output "Target: Call group"
        Write-Output "Group membership details:"
        Write-Output "$($StatusQuo_Forward.GroupMembershipDetails)"
    }
    elseif ($StatusQuo_Forward.ForwardingTargetType -like "MyDelegates") {
        Write-Output "Target: Delegates"
        Write-Output "Delegates and delegate Settings:"
        Write-Output "$($StatusQuo_Forward.Delegates)"
    }
}
else {
    Write-Output "Immediate call forwarding is not active"
}

#endregion

########################################################
#region Teams Call Queue membership
##
########################################################

Write-Output ""
Write-Output "Teams Call Queue membership:"
# Get ObjectID of the user
$ObjectID = $StatusQuo.Identity

# Check if the user is directly assigned to any call queue
$userAssignedQueues = @()
foreach ($queue in $callQueues) {
    if ($queue.Agents.ObjectId -contains $ObjectID) {
        $userAssignedQueues += $queue
    }
}

if ($userAssignedQueues.Count -gt 0) {
    $userAssignedQueues | ForEach-Object { Write-Output $_.Name }
}
else {
    Write-Output "The user is not member of any call queue."
}

#endregion

########################################################
#region License check
##
########################################################

Write-Output ""
Write-Output "Enterprise Voice (for PSTN) - License check:"
Write-Output "---------------------"

$AssignedPlan = $StatusQuo.AssignedPlan

if ($AssignedPlan.Capability -like "MCOSTANDARD" -or $AssignedPlan.Capability -like "MCOEV" -or $AssignedPlan.Capability -like "MCOEV-*" -or $AssignedPlan.Capability -like "MCOEV_VIRTUALUSER") {
    if ($AssignedPlan.Capability -like "MCOEV_VIRTUALUSER") {
        Write-Output "License check - Microsoft Teams Phone Resource Account is assigned to this user"
    }else {
        Write-Output "License check - Microsoft O365 Phone Standard is generally assigned to this user"
    }

    #Validation whether license is already assigned long enough
    $Now = get-date

    $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOSTANDARD").AssignedTimestamp

    if ($LicenseTimeStamp -like "") {
        $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOEV*").AssignedTimestamp
    }
    if ($LicenseTimeStamp -notlike "") {
        try {
            if ($LicenseTimeStamp.AddHours(1) -lt $Now ) {
                Write-Output "$($symbol_check) - The license has already been assigned to the user for more than one hour. Date/time of license assignment: $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss"))"
                if (($LicenseTimeStamp.AddHours(24) -gt $Now)) {
                    Write-Output "Note: In some cases, this may not yet be sufficient. It can take up to 24h until the license replication in the backend is completed!"
                }

                $TeamsPhoneSystemAppEnabled = $false
                foreach ($plan in $AssignedPlan) {
                    if ($plan.ServicePlanId -eq "4828c8ec-dc2e-4779-b502-87ac9ce28ab7" -and $plan.CapabilityStatus -eq "Deleted") {
                        $TeamsPhoneSystemAppEnabled = $false
                        break
                    }
                    elseif ($plan.ServicePlanId -eq "4828c8ec-dc2e-4779-b502-87ac9ce28ab7" -and $plan.CapabilityStatus -eq "Enabled") {
                        $TeamsPhoneSystemAppEnabled = $true
                        break
                    }
                    else {
                        $TeamsPhoneSystemAppEnabled = $false
                        break
                    }
                }

                if ($TeamsPhoneSystemAppEnabled) {
                    Write-Output "$($symbol_check) - The application Teams Phone System from the assigned license is enabled."
                }
                else {
                    Write-Output "WARNING: The application Teams Phone System from the assigned license is NOT enabled or could not be verified!"
                }

            }
            else {
                Write-Output ""
                Write-Warning "Error:"
                Write-Warning "The license should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. "
                Write-Warning "The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Provisions regarding telephony not before: ($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss"))"
            }
        }
        catch {
            Write-Warning "Warning: The time of license assignment could not be verified!"
        }
    }
    else {
        Write-Warning "Warning: The time of license assignment could not be verified!"
    }

}
else {
    Write-Output ""
    Write-Output "License check - No License which includes Microsoft O365 Phone Standard is assigned to this user!"
}
#endregion

Write-Output ""
Write-Output "Done!"