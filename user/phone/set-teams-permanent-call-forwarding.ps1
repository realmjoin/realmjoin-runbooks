<#
  .SYNOPSIS
  Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user.

  .DESCRIPTION
  Set up instant call forwarding for a Microsoft Teams Enterprise Voice user. Forwarding to another Microsoft Teams Enterprise Voice user or to an external phone number.

  .PARAMETER UserName
  User which should be set up. Could be filled with the user picker in the UI.

  .PARAMETER ForwardTargetPhoneNumber
  Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789).

  .PARAMETER ForwardTargetTeamsUser
  Teams user to which calls should be forwarded. Could be filled with the user picker in the UI.

  .PARAMETER ForwardToVoicemail
  Forward calls to voicemail.

  .PARAMETER ForwardToDelegates
  Forward calls to delegates which are defined by the user.

  .PARAMETER TurnOffForward
  Turn off immediate call forwarding.

  .INPUTS
  RunbookCustomization: {
	"ParameterList": [
      {
			"Name": "UserName",
			"DisplayName": "UPN of the current user"
		},
		{
			"Name": "ForwardTargetPhoneNumber",
			"DisplayName": "To which phone number should calls be forwarded?"
		},
		{
			"Name": "ForwardTargetTeamsUser",
			"DisplayName": "To which Teams user should calls be forwarded?"
		},
		{
			"DisplayName": "To which destination should calls be forwarded?",
			"DisplayAfter": "UserName",
			"Select": {
				"Options": [{
						"Display": "Teams user",
						"Customization": {
							"Hide": [
								"ForwardTargetPhoneNumber"
							],
							"Mandatory": [
								"ForwardTargetTeamsUser"
							],
                            "Default": {
                                "ForwardToVoicemail": false,
                                "ForwardToDelegates": false,
                                "TurnOffForward": false,
                                "ForwardTargetPhoneNumber": ""
                            }
						}
					},
					{
						"Display": "Phone number",
						"Customization": {
							"Hide": [
								"ForwardTargetTeamsUser"
							],
							"Mandatory": [
								"ForwardTargetPhoneNumber"
							],
                            "Default": {
                                "ForwardToVoicemail": false,
                                "ForwardToDelegates": false,
                                "TurnOffForward": false,
                                "ForwardTargetTeamsUser": ""
                            }
						}
					},
					{
						"Display": "Voicemail",
						"Customization": {
							"Hide": [
								"ForwardTargetTeamsUser",
                                "ForwardTargetPhoneNumber"
							],
                            "Default": {
                                "ForwardToVoicemail": true,
                                "ForwardToDelegates": false,
                                "TurnOffForward": false,
                                "ForwardTargetPhoneNumber": "",
                                "ForwardTargetTeamsUser": ""
                            }
						}
					},
					{
						"Display": "Delegates which are defined by the user",
						"Customization": {
							"Hide": [
								"ForwardTargetTeamsUser",
                                "ForwardTargetPhoneNumber"
							],
                            "Default": {
                                "ForwardToVoicemail": false,
                                "ForwardToDelegates": true,
                                "TurnOffForward": false,
                                "ForwardTargetPhoneNumber": "",
                                "ForwardTargetTeamsUser": ""
                            }
						}
					},
					{
						"Display": "Nowhere - Turn off immediate forwarding",
						"Customization": {
							"Hide": [
								"ForwardTargetTeamsUser",
                                "ForwardTargetPhoneNumber"
							],
                            "Default": {
                                "ForwardToVoicemail": false,
                                "ForwardToDelegates": false,
                                "TurnOffForward": true,
                                "ForwardTargetPhoneNumber": "",
                                "ForwardTargetTeamsUser": ""
                            }
						}
					}
				]

			},
			"Default": "Teams user"
		},
		{
			"Name": "ForwardToVoicemail",
			"Hide": true
		},
		{
			"Name": "ForwardToDelegates",
			"Hide": true
		},
		{
			"Name": "TurnOffForward",
			"Hide": true
		},
		{
			"Name": "CallerName",
			"Hide": true
		}
	]
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.8.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String] $UserName,

    [String] $ForwardTargetPhoneNumber,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Forward Target Teams user" } )]
    [String] $ForwardTargetTeamsUser,

    [bool] $ForwardToVoicemail,
    [bool] $ForwardToDelegates,
    [bool] $TurnOffForward,

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

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "ForwardTargetPhoneNumber: $ForwardTargetPhoneNumber" -Verbose
Write-RjRbLog -Message "ForwardTargetTeamsUser: $ForwardTargetTeamsUser" -Verbose
Write-RjRbLog -Message "ForwardToVoicemail: $ForwardToVoicemail" -Verbose
Write-RjRbLog -Message "ForwardToDelegates: $ForwardToDelegates" -Verbose
Write-RjRbLog -Message "TurnOffForward: $TurnOffForward" -Verbose

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
    $StatusQuo = Get-CsUserCallingSettings -Identity $UserName
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

if (($StatusQuo.IsForwardingEnabled -eq $true) -and ($StatusQuo.ForwardingType -like "Immediate")) {
    Write-Output "Immediate call forward is active"
    if ($StatusQuo.ForwardingTargetType -like "SingleTarget" ) {
        Write-Output "Target: $($StatusQuo.ForwardingTarget )"
    }
    elseif ($StatusQuo.ForwardingTargetType -like "Voicemail") {
        Write-Output "Target: Voicemail"
    }
    elseif ($StatusQuo.ForwardingTargetType -like "Group") {
        Write-Output "Target: Call group"
        Write-Output "Group membership details:"
        Write-Output "$($StatusQuo.GroupMembershipDetails)"
    }
    elseif ($StatusQuo.ForwardingTargetType -like "MyDelegates") {
        Write-Output "Target: Delegates"
        Write-Output "Current delegates and delegate Settings:"
        Write-Output "$($StatusQuo.Delegates)"
    }
}
else {
    Write-Output "No immediate call forwarding is active"
}

if ($ForwardTargetPhoneNumber -notlike "") {
    Write-Output ""
    Write-Output "Preflight-Check"
    Write-Output "---------------------"

    # Check if number is E.164
    if ($ForwardTargetPhoneNumber -notmatch "^\+\d{8,15}") {
        Write-Error -Message  "Error: Phone number needs to be in E.164 format ( '+#######...' )." -ErrorAction Continue
        throw "Phone number needs to be in E.164 format ( '+#######...' )."
    }
    else {
        Write-Output "Phone number is in the correct E.164 format (Number: $ForwardTargetPhoneNumber)."
    }
}

if ($ForwardToDelegates) {
    Write-Output ""
    Write-Output "Preflight-Check"
    Write-Output "---------------------"
    $CurrentDelegates = ($StatusQuo.Delegates | Measure-Object).Count
    if ($CurrentDelegates -eq 0) {
        Write-Error -Message "If selecting call forward to My Delegates, there needs to be at least 1 delegate defined. Stopping script!" -ErrorAction Continue
        throw "If selecting call forward to My Delegates, there needs to be at least 1 delegate defined. Stopping script!"
    }
    else {
        Write-Output "There is at least one delegate - check ok!"
    }

}
########################################################
##             Main Part
##
########################################################
Write-Output ""
Write-Output "Start set process"
Write-Output "---------------------"
if ($TurnOffForward) {
    Write-Output "Turn off immediate forwarding"
    Set-CsUserCallingSettings -Identity $UserName -IsForwardingEnabled $false
}
elseif ($ForwardToVoicemail) {
    Write-Output "Set immediate forwarding to Voicemail"
    Set-CsUserCallingSettings -Identity $UserName -IsUnansweredEnabled $false
    Set-CsUserCallingSettings -Identity $UserName -IsForwardingEnabled $true -ForwardingType Immediate -ForwardingTargetType Voicemail
}
elseif ($ForwardToDelegates) {
    Write-Output "Set immediate forwarding to the delegates which are defined by the user"
    Set-CsUserCallingSettings -Identity $UserName -IsUnansweredEnabled $false
    Set-CsUserCallingSettings -Identity $UserName -IsForwardingEnabled $true -ForwardingType Immediate -ForwardingTargetType MyDelegates
}
elseif ($ForwardTargetTeamsUser -notlike "" ) {
    Write-Output "Set immediate forwarding to Teams user"
    Set-CsUserCallingSettings -Identity $UserName -IsUnansweredEnabled $false
    Set-CsUserCallingSettings -Identity $UserName -IsForwardingEnabled $true -ForwardingType Immediate -ForwardingTargetType SingleTarget -ForwardingTarget $ForwardTargetTeamsUser
}
elseif ($ForwardTargetPhoneNumber -notlike "" ) {
    Write-Output "Set immediate forwarding to phone number"
    Set-CsUserCallingSettings -Identity $UserName -IsUnansweredEnabled $false
    Set-CsUserCallingSettings -Identity $UserName -IsForwardingEnabled $true -ForwardingType Immediate -ForwardingTargetType SingleTarget -ForwardingTarget $ForwardTargetPhoneNumber
}

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null