<#
  .SYNOPSIS
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. 
  
  .DESCRIPTION
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
  If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
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
        "PhoneNumber": {
            "DisplayName": "Phone number to assign (E.164 Format - Example:+49123987654"
        },
        "OnlineVoiceRoutingPolicy": {
            "DisplayName": "Microsoft Teams OnlineVoiceRoutingPolicy Name"
        },
        "TenantDialPlan": {
            "DisplayName": "Microsoft Teams DialPlan Name"
        },
        "TeamsCallingPolicy": {
            "DisplayName": "Microsoft Teams CallingPolicy Name"
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

    #Number which should be assigned
    [parameter(Mandatory = $true)]
    [String] $PhoneNumber,

    [parameter(Mandatory = $true)]
    [String] $OnlineVoiceRoutingPolicy,

    [parameter(Mandatory = $false)]
    [String] $TenantDialPlan,

    [parameter(Mandatory = $false)]
    [String] $TeamsCallingPolicy,

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

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

Write-Output "Current LineUri: $CurrentLineUri"
Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"

Write-Output ""
Write-Output "Preflight-Check"

$AssignedPlan = $StatusQuo.AssignedPlan

if ($AssignedPlan.Capability -like "MCOSTANDARD" -or $AssignedPlan.Capability -like "MCOEV" -or $AssignedPlan.Capability -like "MCOEV-*") {
    Write-Output "License check - Microsoft O365 Phone Standard is generally assigned to this user"
}else {
    Write-Output ""
    Write-Error "Error:"
    Write-Error "The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)"
    throw "The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)"
    Exit
}


# Check if number is E.164
if ($PhoneNumber -notmatch "^\+\d{8,15}") {
    Write-Error  "Phone number needs to be in E.164 format ( '+#######...' )."
    throw "Phone number needs to be in E.164 format ( '+#######...' )."
}else {
    Write-Output "Phone number is in the correct E.164 format (Number: $PhoneNumber)."
}

# Check if number is already assigned
$NumberCheck = "Empty"
$CleanNumber = "tel:+"+($PhoneNumber.Replace("+",""))
$NumberCheck = (Get-CsOnlineUser | Where-Object LineURI -Like "*$CleanNumber*").UserPrincipalName

if ($NumberCheck -notlike "") {
    Write-Error  "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned to $NumberCheck"
    throw "The assignment for could not be performed. PhoneNumber is already assigned!"
}else {
    Write-Output "Phone number is not yet assigned to a Microsoft Teams user"
}

#Check if number is a calling plan number
Write-Output "Check if LineUri is a Calling Plan number"
$CallingPlanNumber = (Get-CsPhoneNumberAssignment -NumberType CallingPlan).TelephoneNumber
if ($CallingPlanNumber.Count -gt 0) {
    if ($CallingPlanNumber -contains $PhoneNumber) {
        $CallingPlanCheck = $true
        Write-Output "Phone number is a Calling Plan number"
    }else{
        $CallingPlanCheck = $false
        Write-Output "Phone number is a Direct Routing number"
    }
}else{
    Write-Output "Phone number is a Direct Routing number"
    $CallingPlanCheck = $false
}



########################################################
##             Main Part
##          
########################################################
Write-Output ""
Write-Output "Start set process"

Write-Output "Set $PhoneNumber to $UPN"
try {
    if ($CallingPlanCheck) {
        Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType CallingPlan -ErrorAction Stop
    }else {
        Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType DirectRouting -ErrorAction Stop
    }
}catch {
    $message = $_
    Write-Error "Teams - Error: The assignment for $UPN could not be performed!"
    Write-Error "Error Message: $message"
    throw "Teams - Error: The assignment for $UPN could not be performed! Further details in ""All Logs"""
}

if (($OnlineVoiceRoutingPolicy -notlike "") -and ($TenantDialPlan -notlike "") -and ($TeamsCallingPolicy -notlike "")) {
    Write-Output "Grant Policies these policies to $UPN :"

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
}



Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null