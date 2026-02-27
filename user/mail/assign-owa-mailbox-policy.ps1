<#
    .SYNOPSIS
    Assign an OWA mailbox policy to a user

    .DESCRIPTION
    Assigns an OWA mailbox policy to a mailbox in Exchange Online.
    This can be used to enable or restrict features such as the ability to use email signatures in OWA or to enable the Bookings add-in for users who create Bookings appointments.

    .PARAMETER UserName
    User principal name of the target mailbox.

    .PARAMETER OwaPolicyName
    Name of the OWA mailbox policy to assign.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "OwaPolicyName": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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

$Version = "1.1.0"

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

