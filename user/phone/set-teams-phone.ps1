<#
  .SYNOPSIS
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

  .DESCRIPTION
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
  If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

  .PARAMETER UserName
  User which should be assigned. Could be filled with the user picker in the UI.

  .PARAMETER PhoneNumber
  Phone number which should be assigned to the user. The number must be in E.164 format (e.g. +49123456789).

  .PARAMETER OnlineVoiceRoutingPolicy
  Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

  .PARAMETER TenantDialPlan
  Microsoft Teams DialPlan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

  .PARAMETER TeamsCallingPolicy
  Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

  .PARAMETER TeamsIPPhonePolicy
  Microsoft Teams IP Phone Policy Name (a.o. for Common Area Phone Users). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "PhoneNumber": {
            "DisplayName": "Phone number to assign (E.164 Format - Example:+49123987654"
        },
        "OnlineVoiceRoutingPolicy": {
            "DisplayName": "Microsoft Teams Online Voice Routing Policy Name"
        },
        "TenantDialPlan": {
            "DisplayName": "Microsoft Teams DialPlan Name"
        },
        "TeamsCallingPolicy": {
            "DisplayName": "Microsoft Teams Calling Policy Name"
        },
        "TeamsIPPhonePolicy": {
            "DisplayName": "Microsoft Teams IP Phone Policy Name (a.o. for Common Area Phone Users)"
        },
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

    #Number which should be assigned
    [parameter(Mandatory = $true)]
    [String] $PhoneNumber,

    [parameter(Mandatory = $false)]
    [String] $OnlineVoiceRoutingPolicy,

    [parameter(Mandatory = $false)]
    [String] $TenantDialPlan,

    [parameter(Mandatory = $false)]
    [String] $TeamsCallingPolicy,

    [parameter(Mandatory = $false)]
    [String] $TeamsIPPhonePolicy,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
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
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "PhoneNumber: $PhoneNumber" -Verbose
Write-RjRbLog -Message "OnlineVoiceRoutingPolicy: $OnlineVoiceRoutingPolicy" -Verbose
Write-RjRbLog -Message "TenantDialPlan: $TenantDialPlan" -Verbose
Write-RjRbLog -Message "TeamsCallingPolicy: $TeamsCallingPolicy" -Verbose
Write-RjRbLog -Message "TeamsIPPhonePolicy: $TeamsIPPhonePolicy" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

Write-Output "Connect to Microsoft Teams..."

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
        Write-Error "Microsoft Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

#endregion

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

$CurrentLineUri = $StatusQuo.LineURI -replace ("tel:", "")

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") {
    $CurrentLineUri = "none"
}

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
                Write-Output "The license has already been assigned to the user for more than one hour. Date/time of license assignment: $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss"))"
                if (($LicenseTimeStamp.AddHours(24) -gt $Now)) {
                    Write-Output "Note: In some cases, this may not yet be sufficient. It can take up to 24h until the license replication in the backend is completed!"
                }

            }
            else {
                Write-Output ""
                Write-Error -Message "Error: The user license should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Please try again at $($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")) (MCOEV - Microsoft O365 Phone Standard)"  -ErrorAction Continue
                throw "The user license should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Please try again at $($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")) (MCOEV - Microsoft O365 Phone Standard)"
                Exit
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
    Write-Error -Message "Error: The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)" -ErrorAction Continue
    throw "The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)"
    Exit
}


# Check if number is E.164
if ($PhoneNumber -notmatch "^\+\d{8,15}(;ext=\d{1,10})?") {
    Write-Error -Message  "Error: Phone number needs to be in E.164 format ( '+#######...' )." -ErrorAction Continue
    throw "Phone number needs to be in E.164 format ( '+#######...' )."
}
else {
    if ($PhoneNumber -match "^\+\d{8,15}") {
        Write-Output "Phone number is in the correct E.164 format (Number: $PhoneNumber)."
    }
    else {
        Write-Output "Phone number is in the correct E.164 with extension format (Number: $PhoneNumber)."
    }
}

# Check if number is already assigned
$NumberCheck = "Empty"
$CleanNumber = "tel:+" + ($PhoneNumber.Replace("+", ""))
$NumberCheck = (Get-CsOnlineUser | Where-Object LineURI -Like "*$CleanNumber").UserPrincipalName
$NumberAlreadyAssigned = 0

if ($NumberCheck -notlike "") {
    if ($UPN -like $Numbercheck) {
        #Check if number is already assigned to the target user
        $NumberAlreadyAssigned = 1
        Write-Output "Phone number is already assigned to the user!"
    }
    else {
        Write-Error -Message  "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned to $NumberCheck" -ErrorAction Continue
        throw "The assignment for could not be performed. PhoneNumber is already assigned!"
    }
}
else {
    Write-Output "Phone number is not yet assigned to a Microsoft Teams user"
}

#Check if number is a calling plan number
Write-Output "Check if LineUri is a Calling Plan number"
$CallingPlanNumber = (Get-CsPhoneNumberAssignment -NumberType CallingPlan).TelephoneNumber
if ($CallingPlanNumber.Count -gt 0) {
    if ($CallingPlanNumber -contains $PhoneNumber) {
        $CallingPlanCheck = $true
        Write-Output "Phone number is a Calling Plan number"
    }
    else {
        $CallingPlanCheck = $false
        Write-Output "Phone number is a Direct Routing number"
    }
}
else {
    Write-Output "Phone number is a Direct Routing number"
    $CallingPlanCheck = $false
}

if ($OnlineVoiceRoutingPolicy -notlike "") {
    Write-Output "Check if Online Voice Routing Policy exist"
    # Check if specified Online Voice Routing Policy exists
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
        throw "The specified Online Voice Routing Policy could not be found in the tenant!"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}

if ($CallingPlanCheck -eq $false -and ($OnlineVoiceRoutingPolicy -like "")) {
    Write-Warning "NOTE! - the number is not a Calling Plan number and should therefore be a Direct Routing number. However, no online voice routing policy was submitted! For outgoing telephony to work, the routing MUST be defined in the global online voice routing policy!"
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
        throw "The specified Tenant Dial Plan could not be found in the tenant!"
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
        throw "The specified Teams Calling Policy could not be found in the tenant!"
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
        throw "The specified Teams IP-Phone Policy could not be found in the tenant!"
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


########################################################
##             Main Part
##
########################################################
Write-Output ""
Write-Output "Start set process"
Write-Output "---------------------"

if ($NumberAlreadyAssigned -like 1) {
    Write-Output "Number $PhoneNumber is already set to $UPN - skip phone number assignment"
}
else {
    Write-Output "Set $PhoneNumber to $UPN"
    try {
        if ($CallingPlanCheck) {
            Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType CallingPlan -ErrorAction Stop
        }
        else {
            Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType DirectRouting -ErrorAction Stop
        }
    }
    catch {
        $message = $_
        Write-Error -Message "Teams - Error: The assignment for $UPN could not be performed! Error Message: $message" -ErrorAction Continue
        throw "Teams - Error: The assignment for $UPN could not be performed! Further details in ""All Logs"""
    }
}

if (($OnlineVoiceRoutingPolicy -notlike "") -or ($TenantDialPlan -notlike "") -or ($TeamsCallingPolicy -notlike "") -or ($TeamsIPPhonePolicy -notlike "") -or ($OnlineVoicemailPolicy -notlike "")) {
    Write-Output ""
    Write-Output "Grant Policies policies to $UPN :"

    # Grant OnlineVoiceRoutingPolicy if defined
    if ($OnlineVoiceRoutingPolicy -notlike "") {
        Write-Output "Online Voice Routing Policy: $OnlineVoiceRoutingPolicy"
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

    # Grant TenantDialPlan if defined
    if ($TenantDialPlan -notlike "") {
        Write-Output "Tenant Dial Plan: $TenantDialPlan"
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

    # Grant TeamsCallingPolicy if defined
    if ($TeamsCallingPolicy -notlike "") {
        Write-Output "Calling Policy: $TeamsCallingPolicy"
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

    # Grant TeamsIPPhonePolicy if defined
    if ($TeamsIPPhonePolicy -notlike "") {
        Write-Output "IP-Phone Policy: $TeamsIPPhonePolicy"
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

}

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null