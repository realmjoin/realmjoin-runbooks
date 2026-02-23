<#
    .SYNOPSIS
    Assign an OWA mailbox policy to a user

    .DESCRIPTION
    Assigns an OWA mailbox policy to a mailbox in Exchange Online. This can be used to enable or restrict features such as Microsoft Bookings.

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
                    "BookingsCreators": "BookingsCreators"
                }
            },
            "CallerName": {
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
    [Parameter(Mandatory = $true)]
    [string] $OwaPolicyName = "OwaMailboxPolicy-Default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbExchangeOnline

try {
    $policy = Get-OwaMailboxPolicy -Identity $OwaPolicyName -ErrorAction Stop
}
catch {
    "## Could not read OWA Policy '$OwaPolicyName'. Exiting."
    ""
    throw $_
}


try {
    $targetMBox = Get-Mailbox -Identity $UserName -ErrorAction Stop
}
catch {
    "## Could not find/read '$UserName'. Exiting"
    ""
    throw $_
}

Set-CasMailbox -OwaMailboxPolicy $OwaPolicyName -Identity $UserName -ErrorAction Stop | Out-Null
"## OWA Mailbox Policy for '$Username' set to '$OwaPolicyName'."

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

