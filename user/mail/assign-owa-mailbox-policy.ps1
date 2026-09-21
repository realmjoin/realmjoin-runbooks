<#
    .SYNOPSIS
    Assign an Outlook on the web policy to this user's mailbox

    .DESCRIPTION
    Assigns an Outlook on the web (OWA) mailbox policy to the mailbox of this user. Policies switch features on or off, for example email signatures in the web client or the Bookings add-in for people who create Bookings appointments. Get current assignment shows the policy in place without changing it.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER OwaPolicyName
    Policy to assign. Get current assignment only shows which policy the mailbox has today.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "OwaPolicyName": {
                "DisplayName": "Policy",
                "SelectSimple": {
                    "Default": "OwaMailboxPolicy-Default",
                    "No signatures": "OwaMailboxPolicy-NoSignatures",
                    "Bookings creators": "BookingsCreators",
                    "Get current assignment": "GetCurrent"
                }
            },
            "CallerName": {
                "Hide": true
            },
            "UserName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)][ValidateSet("OwaMailboxPolicy-Default", "OwaMailboxPolicy-NoSignatures", "BookingsCreators", "GetCurrent")]
    [string] $OwaPolicyName = "OwaMailboxPolicy-Default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region Variables
#
############################################################

$Version = "1.1.1"

#endregion Variables

############################################################

############################################################
#region Main Logic
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbExchangeOnline

try {
    $null = Get-Mailbox -Identity $UserName -ErrorAction Stop
}
catch {
    "## Could not find/read '$UserName'. Exiting"
    ""
    throw $_
}

if ($OwaPolicyName -eq "GetCurrent") {
    try {
        $casMailbox = Get-CasMailbox -Identity $UserName -ErrorAction Stop
    }
    catch {
        "## Could not read CAS mailbox settings for '$UserName'. Exiting"
        ""
        throw $_
    }

    $currentPolicy = $casMailbox.OwaMailboxPolicy
    if ([string]::IsNullOrWhiteSpace($currentPolicy)) {
        "## OWA Mailbox Policy for '$UserName' is not set."
    }
    else {
        "## OWA Mailbox Policy for '$UserName' is '$currentPolicy'."
    }

    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    return
}

try {
    $null = Get-OwaMailboxPolicy -Identity $OwaPolicyName -ErrorAction Stop
}
catch {
    "## Could not read OWA Policy '$OwaPolicyName'. Exiting."
    ""
    throw $_
}

Set-CasMailbox -OwaMailboxPolicy $OwaPolicyName -Identity $UserName -ErrorAction Stop | Out-Null
"## OWA Mailbox Policy for '$UserName' set to '$OwaPolicyName'."

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

#endregion Main Logic

############################################################

