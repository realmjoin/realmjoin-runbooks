<#
    .SYNOPSIS
    Configure the booking rules of this room mailbox

    .DESCRIPTION
    Sets the booking rules of this room mailbox: who may book it, whether recurring meetings and conflicts are allowed, and how requests are processed. It also sets how far ahead and how long meetings may be, and the room capacity. All booking settings are written as shown; the capacity only when it is greater than 0.

    .PARAMETER UserName
    User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user.

    .PARAMETER AllBookInPolicy
    Everyone lets all users book the room. Only members of a group restricts booking to the "Booking group".

    .PARAMETER BookInPolicyGroup
    Mail-enabled security group whose members may book the room.

    .PARAMETER AllowRecurringMeetings
    Turn off to decline recurring meeting requests; single meetings are still accepted.

    .PARAMETER AutomateProcessing
    Auto accept books the room automatically. Auto update only marks requests as tentative for a delegate to decide. None leaves requests untouched.

    .PARAMETER BookingWindowInDays
    Requests further ahead than this many days are declined.

    .PARAMETER MaximumDurationInMinutes
    Longest meeting the room accepts, in minutes.

    .PARAMETER AllowConflicts
    Lets overlapping bookings through instead of declining them.

    .PARAMETER Capacity
    Number of seats. Leave at 0 to keep the current value.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "UserName": {
                "Hide": true
            },
            "AutomateProcessing": {
                "DisplayName": "Request processing",
                "SelectSimple": {
                    "Auto accept": "AutoAccept",
                    "Auto update": "AutoUpdate",
                    "None": "None"
                }
            },
            "AllBookInPolicy": {
                "DisplayName": "Who may book the room",
                "Select": {
                    "Options": [
                        {
                            "Display": "Everyone",
                            "Customization": {
                                "Hide": [
                                    "BookInPolicyGroup"
                                ]
                            },
                            "Value": true
                        },
                        {
                            "Display": "Only members of a group",
                            "Value": false
                        }
                    ],
                    "Default": true
                }
            },
            "BookInPolicyGroup": {
                "DisplayName": "Booking group"
            },
            "AllowRecurringMeetings": {
                "DisplayName": "Allow recurring meetings?"
            },
            "BookingWindowInDays": {
                "DisplayName": "Booking window (days)"
            },
            "MaximumDurationInMinutes": {
                "DisplayName": "Maximum duration (minutes)"
            },
            "AllowConflicts": {
                "DisplayName": "Allow conflicting bookings?"
            },
            "Capacity": {
                "DisplayName": "Capacity"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Who may book the room" -Type Setting -Attribute "RoomMailbox.AllBookInPolicy" } )]
    [bool] $AllBookInPolicy = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Booking group" } )]
    [string] $BookInPolicyGroup,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowRecurringMeetings" } )]
    [bool] $AllowRecurringMeetings = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "RoomMailbox.AutomateProcessing" } )]
    [string] $AutomateProcessing = "AutoAccept",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "RoomMailbox.BookingWindowInDays" } )]
    [int] $BookingWindowInDays = 180,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "RoomMailbox.MaximumDurationInMinutes" } )]
    [int] $MaximumDurationInMinutes = 1440,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowConflicts" } )]
    [bool] $AllowConflicts = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Capacity" } )]
    [int] $Capacity = 0,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Configuring Room Mailbox settings for '$UserName'."

try {
    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    Write-RjRbLog -Message "Get Mailbox" -Verbose
    $room = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if ($room.RecipientTypeDetails -ne "RoomMailbox") {
        "## '$UserName' is not a room resource mailbox."
        throw ("not a room mailbox")
    }

    $invokeParams = @{
        AutomateProcessing       = $AutomateProcessing
        AllowRecurringMeetings   = $AllowRecurringMeetings
        BookingWindowInDays      = $BookingWindowInDays
        MaximumDurationInMinutes = $MaximumDurationInMinutes
        AllowConflicts           = $AllowConflicts
        AllBookInPolicy          = $AllBookInPolicy
    }

    if ((-not $AllBookInPolicy) -and $BookInPolicyGroup ) {
        Write-RjRbLog -Message "Get BookInPolicyGroup" -Verbose
        $group = Invoke-RjRbRestMethodGraph -resource "/groups/$BookInPolicyGroup" -odselect "displayname,mailenabled,securityenabled"
        if (-not $group.mailenabled -or -not $group.securityenabled) {
            throw "Group '$($group.DisplayName) ($BookInPolicyGroup)' is not mail-enabled or security-enabled."
        }
        $invokeParams.BookInPolicy = $BookInPolicyGroup
    }

    if ($Capacity -gt 0) {
        "## Updating Room Capacity to $Capacity"
        Set-Place -Identity $UserName -Capacity $Capacity
    }

    "## Will update '$UserName' with the following parameters:"
    [PSCustomObject]$invokeParams | Format-List | Out-String
    Set-CalendarProcessing -Identity $UserName @invokeParams
    ""
    "## Room Mailbox '$UserName' has been updated."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}