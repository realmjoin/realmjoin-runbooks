<#
    .SYNOPSIS
    Check whether a phone number is assigned in Microsoft Teams

    .DESCRIPTION
    Looks up whether a given phone number is assigned to a user in Microsoft Teams. If the phone number is assigned, information about the user and relevant voice policies is returned.

    .PARAMETER PhoneNumber
    The phone number must be in E.164 format. Example: +49321987654 or +49321987654;ext=123. It must start with a '+' followed by the country code and subscriber number, with an optional ';ext=' followed by the extension number, without spaces or special characters.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "PhoneNumber": {
                "DisplayName": "Phone number to check"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>


#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.6.0" }

param(
    [parameter(Mandatory = $true)]
    [String] $PhoneNumber,
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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "PhoneNumber: $PhoneNumber" -Verbose

#endregion

########################################################
#region     Validate parameters
##
########################################################

if ($PhoneNumber -notmatch "^\+\d{1,15}(?:;ext=\d+)?$") {
    Write-Error "The phone number '$PhoneNumber' is not in the required E.164 format (including consideration of possible EXT extensions). Example: +49321987654 or +49321987654;ext=123. Please ensure the phone number starts with a '+' followed by the country code and the subscriber number, with an optional ';ext=' followed by the extension number, with no spaces or special characters."
    Exit
}

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
#region     Lookup Part
##
########################################################

Write-Output "Lookup phone number assignment..."
try {
    $CheckResult = Get-CsPhoneNumberAssignment -TelephoneNumber $PhoneNumber -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve phone number assignment for $PhoneNumber. Error: $_"
    Exit
}

if ($CheckResult.AssignedPstnTargetId) {
    try {
        $TeamsUser = Get-CsOnlineUser -Identity $CheckResult.AssignedPstnTargetId -ErrorAction Stop
    }
    catch {
        Write-Error "Error retrieving the associated Teams user. The User ID is $($CheckResult.AssignedPstnTargetId). Error: $_"
        Exit
    }

    $CurrentOnlineVoiceRoutingPolicy = if ($TeamsUser.OnlineVoiceRoutingPolicy -like "") { "Global" } else { $TeamsUser.OnlineVoiceRoutingPolicy }
    $CurrentCallingPolicy = if ($TeamsUser.CallingPolicy -like "") { "Global" } else { $TeamsUser.CallingPolicy }
    $CurrentDialPlan = if ($TeamsUser.DialPlan -like "") { "Global" } else { $TeamsUser.DialPlan }
    $CurrentTenantDialPlan = if ($TeamsUser.TenantDialPlan -like "") { "Global" } else { $TeamsUser.TenantDialPlan }

    $output = [PSCustomObject]@{
        "Display Name"                = $TeamsUser.DisplayName
        "User Principal Name"         = $TeamsUser.UserPrincipalName
        "Account Type"                = $TeamsUser.AccountType
        "Phone Number Type"           = $CheckResult.NumberType
        "Online Voice Routing Policy" = $CurrentOnlineVoiceRoutingPolicy
        "Calling Policy"              = $CurrentCallingPolicy
        "Dial Plan"                   = $CurrentDialPlan
        "Tenant Dial Plan"            = $CurrentTenantDialPlan
    }

    Write-Output "`n`n`n"
    Write-Output "Phone number $($PhoneNumber) is assigned to the following Microsoft Teams user:"
    Write-Output "---------------------------------------------"
    $output | Format-List

}
else {
    Write-Output "`n`n`n"
    Write-Output "Result:"
    Write-Output "---------------------------------------------"
    Write-Output "Phone number $($PhoneNumber) is not assigned to a Microsoft Teams user."
}

