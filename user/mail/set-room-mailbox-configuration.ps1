<#
  .SYNOPSIS
  Set room resource policies.

  .DESCRIPTION
  Set room resource policies.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Allow BookIn for everyone" -Type Setting -Attribute "RoomMailbox.AllBookInPolicy" } )]
    [bool] $AllBookInPolicy = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Allow BookIn for members of this group" } )]
    [string] $BookInPolicyGroup,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowRecurringMeetings" } )]
    [bool] $AllowRecurringMeetings = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AutomateProcessing" } )]
    [string] $AutomateProcessing = "AutoAccept",                               
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.BookingWindowInDays" } )]
    [int] $BookingWindowInDays = 180,                               
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.MaximumDurationInMinutes" } )]
    [int] $MaximumDurationInMinutes = 1440,                       
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowConflicts" } )]
    [bool] $AllowConflicts = $false,                              
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

"## Configuring Room Mailbox settings for '$UserName'."

try {
    Connect-RjRbExchangeOnline

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
        $invokeParams.BookInPolicy = $BookInPolicyGroup
    }

    "## Will update '$UserName' with the following parameters:"
    [PSCustomObject]$invokeParams | Format-List | Out-String 
    
    Set-CalendarProcessing -Identity $UserName @invokeParams

    "## Room Mailbox '$UserName' has been updated."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}