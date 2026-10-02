<#
	.SYNOPSIS
	Check whether a phone number is assigned in Microsoft Teams

	.DESCRIPTION
	Looks up whether a phone number is assigned to a user in Microsoft Teams. If it is, the user and their voice policies are shown in the Output Data tab. Nothing is changed.

	.PARAMETER PhoneNumber
	Number in international format without spaces, for example +49321987654, optionally with an extension as +49321987654;ext=123.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"PhoneNumber": {
				"DisplayName": "Phone number"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.9.0" }

param(
    [parameter(Mandatory = $true)]
    [String] $PhoneNumber,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "PhoneNumber: $PhoneNumber" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ($PhoneNumber -notmatch "^\+\d{1,15}(?:;ext=\d+)?$") {
    $validationMessage = "The phone number '$PhoneNumber' is not in the required E.164 format (including consideration of possible EXT extensions). Example: +49321987654 or +49321987654;ext=123. Please ensure the phone number starts with a '+' followed by the country code and the subscriber number, with an optional ';ext=' followed by the extension number, with no spaces or special characters."
    Write-Error $validationMessage -ErrorAction Continue
    throw $validationMessage
}

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output "Connect to Microsoft Teams..."

$previousVerbosePreference = $VerbosePreference
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MicrosoftTeams -Identity -ErrorAction Stop | Out-Null
    # Check if Teams connection is active
    Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    try {
        Connect-MicrosoftTeams -Identity -ErrorAction Stop | Out-Null
        # Check if Teams connection is active
        Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {
        $VerbosePreference = $previousVerbosePreference
        Write-Error "Microsoft Teams PowerShell session could not be established: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}
$VerbosePreference = $previousVerbosePreference

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Lookup phone number assignment for $($PhoneNumber)..."

try {
    $checkResult = Get-CsPhoneNumberAssignment -TelephoneNumber $PhoneNumber -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve phone number assignment for $($PhoneNumber): $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue | Out-Null
    throw
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

$assignmentRows = @()

if ($checkResult.AssignedPstnTargetId) {
    try {
        $teamsUser = Get-CsOnlineUser -Identity $checkResult.AssignedPstnTargetId -ErrorAction Stop
    }
    catch {
        Write-Error "Error retrieving the associated Teams user (ID $($checkResult.AssignedPstnTargetId)): $($_.Exception.Message)" -ErrorAction Continue
        Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue | Out-Null
        throw
    }

    # An empty policy means the Global (tenant default) policy applies
    $currentOnlineVoiceRoutingPolicy = if ([string]::IsNullOrEmpty("$($teamsUser.OnlineVoiceRoutingPolicy)")) { "Global" } else { "$($teamsUser.OnlineVoiceRoutingPolicy)" }
    $currentCallingPolicy = if ([string]::IsNullOrEmpty("$($teamsUser.CallingPolicy)")) { "Global" } else { "$($teamsUser.CallingPolicy)" }
    $currentDialPlan = if ([string]::IsNullOrEmpty("$($teamsUser.DialPlan)")) { "Global" } else { "$($teamsUser.DialPlan)" }
    $currentTenantDialPlan = if ([string]::IsNullOrEmpty("$($teamsUser.TenantDialPlan)")) { "Global" } else { "$($teamsUser.TenantDialPlan)" }

    $assignmentRows = @([PSCustomObject]@{
            "Phone Number"                = $PhoneNumber
            "Display Name"                = $teamsUser.DisplayName
            "User Principal Name"         = $teamsUser.UserPrincipalName
            "Account Type"                = $teamsUser.AccountType
            "Phone Number Type"           = $checkResult.NumberType
            "Online Voice Routing Policy" = $currentOnlineVoiceRoutingPolicy
            "Calling Policy"              = $currentCallingPolicy
            "Dial Plan"                   = $currentDialPlan
            "Tenant Dial Plan"            = $currentTenantDialPlan
        })

    Write-Output "Phone number $($PhoneNumber) is assigned to $($teamsUser.UserPrincipalName)."
}
else {
    Write-Output "Phone number $($PhoneNumber) is not assigned to a Microsoft Teams user."
}

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. A marker is only written when rows follow it.
Write-Output ""

if ($assignmentRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Phone number assignment" })
    Write-Output $assignmentRows
}
else {
    Write-Output "No assignment found, so there is no table to show."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
