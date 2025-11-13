<#
  .SYNOPSIS
  Get the status quo of a Microsoft Teams user in terms Teams Enterprise Voice, including license verification and config drift detection based on Teams Phone Inventory Location Defaults.

  .DESCRIPTION
  Get the status quo of a Microsoft Teams user in terms Teams Enterprise Voice, including license verification and config drift detection based on Teams Phone Inventory Location Defaults.
  The runbook is part of the TeamsPhoneInventory.

  .NOTES
  Version Changelog:
  1.0.1 - 2025-03-07 - Fix region handling
                     - Add handling of group based policy assignments
                     - Enhanced based on the non TPI version

  Permissions:
  MS Graph (API):
  - Organization.Read.All

  RBAC:
  - Teams Administrator

 .INPUTS
  RunbookCustomization: {
      "Parameters": {
          "SharepointSite": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointTPIList": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointLocationDefaultsList": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointUserMappingList": {
              "Hide": true,
              "Mandatory": true
          },
          "CallerName": {
              "Hide": true
          }
      }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.5.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.32.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,

    # TPI parameters - needs to be configured in RealmJoin Runbook Customization!
    # See Section "Runbook Customization" in Documentation for further Details
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
    [string] $SharepointSite,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
    [string] $SharepointTPIList,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationDefaultsList" } )]
    [String] $SharepointLocationDefaultsList,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointUserMappingList" } )]
    [String] $SharepointUserMappingList,
    # CallerName is tracked purely for auditing purposes
    [string] $CallerName
)

########################################################
#region RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose
Write-RjRbLog -Message "SharepointLocationDefaultsList: '$SharepointLocationDefaultsList'" -Verbose
Write-RjRbLog -Message "SharepointUserMappingList: '$SharepointUserMappingList'" -Verbose

#endregion

########################################################
#region function declaration
##
########################################################
function Get-TPIList {
    param (
        [parameter(Mandatory = $true)]
        [String]
        $ListBaseURL,
        [parameter(Mandatory = $false)]
        [String]
        $ListName # Only for easier logging
    )
    #Limit access to 2000 items (Default is 200)
    $GraphAPIUrl_StatusQuoSharepointList = $ListBaseURL + '/items?expand=fields'
    try {
        $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8'
    }
    catch {
        Write-Warning "First try to get TPI list failed - reconnect MgGraph and test again"

        try {
            Connect-MgGraph -Identity
            $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8'
        }
        catch {
            Write-Error "Getting TPI list failed - stopping script" -ErrorAction Continue
            Exit
        }

    }

    $AllItems = $AllItemsResponse.value.fields
    #Check if response is paged:
    $AllItemsResponseNextLink = $AllItemsResponse."@odata.nextLink"
    while ($null -ne $AllItemsResponseNextLink) {
        $AllItemsResponse = Invoke-MgGraphRequest -Uri $AllItemsResponseNextLink -Method Get -ContentType 'application/json; charset=utf-8'
        $AllItemsResponseNextLink = $AllItemsResponse."@odata.nextLink"
        $AllItems += $AllItemsResponse.value.fields
    }
    return $AllItems
}
function Invoke-TPIRestMethod {
    param (
        [parameter(Mandatory = $true)]
        [String]
        $Uri,
        [parameter(Mandatory = $true)]
        [String]
        $Method,
        [parameter(Mandatory = $false)]
        $Body,
        [parameter(Mandatory = $true)]
        [String]
        $ProcessPart
    )
    #ToFetchErrors (Throw)
    $ExitError = 0
    if (($Method -like "Post") -or ($Method -like "Patch")) {
        try {
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8'
        }
        catch {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - One Retry after 5 seconds"
            Start-Sleep -Seconds 5
            Write-Output "$TimeStamp - GraphAPI - GraphAPI Session refresh"
            #Connect-MgGraph -Identity
            try {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8'
                Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            }
            catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
                $ExitError = 1
            }
        }
    }
    else {
        try {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - Uri $Uri -Method $Method : $ProcessPart"
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method
        }
        catch {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - One Retry after 5 seconds"
            Start-Sleep -Seconds 5
            Write-Output "$TimeStamp - GraphAPI - GraphAPI Session refresh"
            #Connect-MgGraph -Identity
            try {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method
                Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            }
            catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
            }
        }
    }
    if ($ExitError -eq 1) {
        throw "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present! StatusCode: $StatusCode StatusDescription: $StatusDescription"
        $StatusCode = $null
        $StatusDescription = $null
    }
    return $TPIRestMethod

}

########################################################
#region Connect Part
##
########################################################

# Needs a Microsoft Teams Connection First!
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Connect to Microsoft Teams (PowerShell as RealmJoin managed identity)"
$VerbosePreference = "SilentlyContinue"
Connect-MicrosoftTeams -Identity -ErrorAction Stop
$VerbosePreference = "Continue"
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
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}
# Initiate Graph Session
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Initiate MGGraph Session"
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit
}
########################################################
#region Setup base URL
##
########################################################
# Add check symbol to variable, wich is compatible with powershell 5.1
$symbol_check = [char]0x2714
Write-Output ""
Write-Output "Check basic connection to TPI List and build base URL"
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Check basic connection to TPI List"
$SharepointURL = (Invoke-TPIRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root" -Method GET -ProcessPart "Get SharePoint WebURL" ).webUrl
if ($SharepointURL -like "https://*") {
    $SharepointURL = $SharepointURL.Replace("https://", "")
}
elseif ($SharepointURL -like "http://*") {
    $SharepointURL = $SharepointURL.Replace("http://", "")
}
# Setup Base URL - not only for NumberRange etc.
$BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/'
$TPIListURL = $BaseURL + $SharepointTPIList
try {
    Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop | Out-Null
}
catch {
    $BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/'
    $TPIListURL = $BaseURL + $SharepointTPIList
    try {
        Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List"  -ErrorAction Stop | Out-Null
    }
    catch {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Connection - Could not connect to SharePoint TPI List!"
        throw "$TimeStamp - Could not connect to SharePoint TPI List!"
        Exit
    }
}
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - SharePoint TPI List URL: $TPIListURL"
########################################################
#region StatusQuo & Preflight-Check Part
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

if ($AssignedPlan.Capability -like "MCOSTANDARD" -or $AssignedPlan.Capability -like "MCOEV" -or $AssignedPlan.Capability -like "MCOEV-*") {
    Write-Output "$($symbol_check) - License check - Microsoft O365 Phone Standard is generally assigned to this user"

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
                Write-Warning "The user license (MCOEV - Microsoft O365 Phone Standard) should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. "
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

########################################################
#region Teams Phone Inventory (TPI) - Config drift detection
##
########################################################

Write-Output ""
Write-Output "Teams Phone Inventory (TPI) - Config drift detection"
Write-Output "---------------------"
if ($CurrentLineUri -like "none") {
    Write-Output ""
    Write-Output "The user has no phone number assigned. Consequently, since a detection is meaningless, the check will be skipped!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
try {
    Write-Output "Get StatusQuo of the Teams Phone Inventory (TPI) SharePoint List"
    $TPI_AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList
    Write-Output " - Items in $SharepointTPIList SharePoint List: $(($TPI_AllItems | Measure-Object).Count)"
    Write-Output "Get StatusQuo of the TPI User Mapping SharePoint List"
    $TPIUserMappingListURL = $BaseURL + $SharepointUserMappingList
    $TPI_UserMapping_AllItems = Get-TPIList -ListBaseURL $TPIUserMappingListURL -ListName $SharepointUserMappingList
    Write-Output " - Items in $SharepointUserMappingList SharePoint List: $(($TPI_UserMapping_AllItems | Measure-Object).Count)"
    Write-Output "Get StatusQuo of the TPI Location Defaults SharePoint List"
    $TPILocationDefaultsListURL = $BaseURL + $SharepointLocationDefaultsList
    $TPI_LocationDefaults_AllItems = Get-TPIList -ListBaseURL $TPILocationDefaultsListURL -ListName $SharepointLocationDefaultsList
    Write-Output " - Items in $SharepointLocationDefaultsList SharePoint List: $(($TPI_LocationDefaults_AllItems | Measure-Object).Count)"
}
catch {
    Write-Output ""
    Write-Output "The TPI Lists could not be retrieved. The detection of the config drift regarding TPI is therefore stopped!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
Write-Output ""
Write-Output "EntraID Attributes for the current user:"
Write-Output "$($StatusQuo.DisplayName) - $($StatusQuo.UserPrincipalName)"
Write-Output "- Company: $($StatusQuo.Company)"
Write-Output "- City: $($StatusQuo.City)"
Write-Output "- Street: $($StatusQuo.Street) `n"
#Check if the user is in the TPI List (TPI_AllItems), otherwise skip the check, cause it is not possible to validate the extension range
$CurrentTPIUser = $TPI_AllItems | Where-Object Title -Like $CurrentLineUri
if (($CurrentTPIUser | Measure-Object).Count -eq 0) {
    Write-Output ""
    Write-Output "The LineUri (phone number) of the user is not available in the TPI list. The detection of the config drift regarding TPI is therefore stopped!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
$CurrentTPIUser_ExtensionRangeIndex = $CurrentTPIUser.ExtensionRangeIndex
$CurrentTPIUser_CivicAddressMappingIndex = $CurrentTPIUser.CivicAddressMappingIndex
#Get all entries from TPI-UserMapping List which Title (UPN) is like the given UserName
$CurrentUserMapping = $TPI_UserMapping_AllItems | Where-Object Title -Like $UPN
if (($CurrentUserMapping | Measure-Object).Count -eq 1) {
    if ($CurrentUserMapping.LocationIdentifier -notlike "") {
        #If there is exactly one match - go on
        $CurrentLocationIdentifier = $CurrentUserMapping.LocationIdentifier
        Write-Output "The LocationIdentifier of the user is $CurrentLocationIdentifier"
    }
    else {
        Write-Output ""
        Write-Output "There is an entry for the user in the user mapping list, but the LocationIdentifier is empty. The detection of the config drift regarding TPI is therefore stopped!"
        Write-Output ""
        Write-Output "Done!"
        Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
        Get-PSSession | Remove-PSSession | Out-Null
        Exit
    }
}
elseif (($CurrentUserMapping | Measure-Object).Count -gt 1) {
    #If there are duplicates - stop it!
    Write-Output ""
    Write-Output "More than one entry is present in the user mapping table. The detection of the config drift regarding TPI will be stopped now, because no unique mapping is possible!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
elseif (($CurrentUserMapping | Measure-Object).Count -eq 0) {
    #If there is no match - stop it!
    Write-Output ""
    Write-Output "The user is not available in the user mapping list. Either no suitable storage location could be found for the user due to their Azure AD attributes or the user was only created less than an hour ago, so no mapping has been created yet. The detection of the config drift regarding TPI is therefore stopped!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
$RecievedLocationDefaults = $TPI_LocationDefaults_AllItems | Where-Object Title -Like $CurrentLocationIdentifier
Write-Verbose "Current Location Identifier: $CurrentLocationIdentifier"
if (($RecievedLocationDefaults | Measure-Object).Count -eq 1) {
    if ($RecievedLocationDefaults.ExtensionRangeIndex -notlike "" -or $RecievedLocationDefaults.CivicAddressMappingIndex -notlike "") {
        Write-Output ""
        $CivicAddressMappingIndex = $RecievedLocationDefaults.CivicAddressMappingIndex
        if (($RecievedLocationDefaults.ExtensionRangeIndex -notlike "" -and $RecievedLocationDefaults.CivicAddressMappingIndex -notlike "")) {
            Write-Warning "For the current Location Identifier: $CurrentLocationIdentifier both values (ExtensionRange and CivicAdressMapping(CallingPlan)) is filled!"
            Write-Warning "Prefer ExtensionRange and clearing CivicAdressMapping now!"
            $CivicAddressMappingIndex = ""
        }
        Write-Output "Recieved values:"
        $ExtensionRangeIndex = $RecievedLocationDefaults.ExtensionRangeIndex
        if ($ExtensionRangeIndex -notlike "") {
            Write-Output "The ExtensionRangeIndex of the user is $ExtensionRangeIndex"
        }
        elseif ($CivicAddressMappingIndex -notlike "") {
            Write-Output "The CivicAddressMappingIndex of the user is $CivicAddressMappingIndex"
        }

        $OnlineVoiceRoutingPolicy = $RecievedLocationDefaults.OnlineVoiceRoutingPolicy
        if ($OnlineVoiceRoutingPolicy -like "") {
            $OnlineVoiceRoutingPolicy = "Global"
        }
        if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
            $OnlineVoiceRoutingPolicy = "Global"
        }
        Write-Output "The OnlineVoiceRoutingPolicy of the user is $OnlineVoiceRoutingPolicy"
        $TenantDialPlan = $RecievedLocationDefaults.TenantDialPlan
        if ($TenantDialPlan -like "") {
            $TenantDialPlan = "Global"
        }
        if ($TenantDialPlan -like "Global (Org Wide Default)") {
            $TenantDialPlan = "Global"
        }
        Write-Output "The TenantDialPlan of the user is $TenantDialPlan"
        $CallingPolicy = $RecievedLocationDefaults.CallingPolicy
        if ($CallingPolicy -like "") {
            $CallingPolicy = "Global"
        }
        if ($CallingPolicy -like "Global (Org Wide Default)") {
            $CallingPolicy = "Global"
        }
        Write-Output "The CallingPolicy of the user is $CallingPolicy"
    }
    else {
        Write-Output ""
        Write-Output "There is an entry for the current location identifier, but no phone number ranges or civic address mappings are defined for it. The detection of the config drift regarding TPI is therefore stopped!"
        Write-Output ""
        Write-Output "Done!"
        Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
        Get-PSSession | Remove-PSSession | Out-Null
        Exit
    }
}
elseif (($RecievedLocationDefaults | Measure-Object).Count -eq 0) {
    Write-Output ""
    Write-Output "No location defaults could be found for the received location identifier. The detection of the config drift regarding TPI is therefore stopped!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
else {
    Write-Output ""
    Write-Output "More than one entry is present in the location defaults table. The detection of the config drift regarding TPI will be stopped now, because no unique mapping is possible!"
    Write-Output ""
    Write-Output "Done!"
    Exit
}
Write-Output ""
Write-Output "Final check whether there is a drift from the location defaults:"
Write-Output "Phone number:"
Write-Output "-------------"
Write-Output "Current number: $CurrentLineUri"
if ($RecievedLocationDefaults.ExtensionRangeIndex -notlike "") {
    if ($RecievedLocationDefaults.ExtensionRangeIndex -notlike $CurrentTPIUser_ExtensionRangeIndex) {
        Write-Output "<- Extension Range Index Drift detected! ->"
        Write-Output "The Extension Range Index from the current phone number of the user is $CurrentTPIUser_ExtensionRangeIndex, but the expected value is $($RecievedLocationDefaults.ExtensionRangeIndex), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "The Extension Range Index from the current phone number of the user is $CurrentTPIUser_ExtensionRangeIndex and matches to the location defaults."
    }
}
if ($RecievedLocationDefaults.CivicAddressMappingIndex -notlike "") {
    if ($RecievedLocationDefaults.CivicAddressMappingIndex -notlike $CurrentTPIUser_CivicAddressMappingIndex) {
        Write-Output "<- Civic Address Mapping Index Drift detected! ->"
        Write-Output "The Civic Address Mapping Index from the current phone number of the user is $CurrentTPIUser_CivicAddressMappingIndex, but the expected value is $($RecievedLocationDefaults.CivicAddressMappingIndex), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "The Civic Address Mapping Index from the current phone number of the user is $CurrentTPIUser_CivicAddressMappingIndex and matches to the location defaults."
    }
}
Write-Output ""
Write-Output "Policies:"
Write-Output "---------"
if ($RecievedLocationDefaults.OnlineVoiceRoutingPolicy -notlike "") {
    if ($RecievedLocationDefaults.OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
        $RecievedLocationDefaults.OnlineVoiceRoutingPolicy = "Global"
    }
    if ($RecievedLocationDefaults.OnlineVoiceRoutingPolicy -notlike $CurrentOnlineVoiceRoutingPolicy) {
        Write-Output "<- OnlineVoiceRoutingPolicy Drift detected! ->"
        Write-Output "The Online Voice Routing Policy of the user is $CurrentOnlineVoiceRoutingPolicy, but the expected value is $($RecievedLocationDefaults.OnlineVoiceRoutingPolicy), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "Online Voice Routing Policy - $CurrentOnlineVoiceRoutingPolicy and matches to the location defaults."
    }
}
else {
    Write-Output "No Online Voice Routing Policy is defined in the location defaults."
}
if ($RecievedLocationDefaults.TeamsCallingPolicy -notlike "") {
    if ($RecievedLocationDefaults.TeamsCallingPolicy -like "Global (Org Wide Default)") {
        $RecievedLocationDefaults.TeamsCallingPolicy = "Global"
    }
    if ($RecievedLocationDefaults.TeamsCallingPolicy -notlike $CurrentCallingPolicy) {
        Write-Output "<- Teams Calling Policy Drift detected! ->"
        Write-Output "The Teams Calling Policy of the user is $CurrentCallingPolicy, but the expected value is $($RecievedLocationDefaults.TeamsCallingPolicy), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "Teams Calling Policy - $CurrentCallingPolicy and matches to the location defaults."
    }
}
else {
    Write-Output "No Teams Calling Policy is defined in the location defaults."
}
if ($RecievedLocationDefaults.TenantDialPlan -notlike "") {
    if ($RecievedLocationDefaults.TenantDialPlan -like "Global (Org Wide Default)") {
        $RecievedLocationDefaults.TenantDialPlan = "Global"
    }
    if ($RecievedLocationDefaults.TenantDialPlan -notlike $CurrentTenantDialPlan) {
        Write-Output "<- Tenant Dial Plan Drift detected! ->"
        Write-Output "The Tenant Dial Plan of the user is $CurrentTenantDialPlan, but the expected value is $($RecievedLocationDefaults.TenantDialPlan), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "Tenant Dial Plan - $CurrentTenantDialPlan and matches to the location defaults."
    }
}
else {
    Write-Output "No Tenant Dial Plan is defined in the location defaults."
}
if ($RecievedLocationDefaults.TeamsIPPhonePolicy -notlike "") {
    if ($RecievedLocationDefaults.TeamsIPPhonePolicy -like "Global (Org Wide Default)") {
        $RecievedLocationDefaults.TeamsIPPhonePolicy = "Global"
    }
    if ($RecievedLocationDefaults.TeamsIPPhonePolicy -notlike $CurrentTeamsIPPhonePolicy) {
        Write-Output "<- Teams IP Phone Policy Drift detected! ->"
        Write-Output "The Teams IP Phone Policy of the user is $CurrentTeamsIPPhonePolicy, but the expected value is $($RecievedLocationDefaults.TeamsIPPhonePolicy), so there is a drift!"
        Write-Output ""
    }
    else {
        Write-Output "Teams IP Phone Policy - $CurrentTeamsIPPhonePolicy and matches to the location defaults."
    }
}
else {
    Write-Output "No Teams IP Phone Policy is defined in the location defaults."
}
Write-Output ""
Write-Output "Done!"