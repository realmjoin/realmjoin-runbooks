<#
  .SYNOPSIS
  Set room resource policies.

  .DESCRIPTION
  Set room resource policies.

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
                "SelectSimple": {
                    "Auto Accept": "AutoAccept",
                    "Auto Update": "AutoUpdate",
                    "None": "None"
                }
            },
			"AllBookInPolicy": {
				"Select": {
                    "Options": [
                        {
                            "Display": "Allow BookIn for everyone",
                            "Customization": {
								"Hide": [
                                    "BookInPolicyGroup"
                                ]
                            },
							"Value": true
                        },
                        {
                            "Display": "Custom BookIn Policy",
                            "Value": false
                        }
                    ],
                    "Default": true
                }
			}
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Allow BookIn for everyone" -Type Setting -Attribute "RoomMailbox.AllBookInPolicy" } )]
    [bool] $AllBookInPolicy = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Allow BookIn for members of this group" } )]
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Capacity (will only update on values greater 0)" } )]
    [int] $Capacity = 0,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
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