<#
    .SYNOPSIS
    Enable or disable out-of-office notifications for a mailbox

    .DESCRIPTION
    Configures automatic replies for a mailbox and optionally creates an out-of-office calendar event. The runbook can either enable scheduled replies or disable them.

    .PARAMETER UserName
    User principal name of the mailbox.

    .PARAMETER Disable
    If set to true, disables out-of-office settings.

    .PARAMETER Start
    Start time for scheduled out-of-office replies.

    .PARAMETER End
    End time for scheduled out-of-office replies. If not specified, defaults to 10 years from the current date.

    .PARAMETER MessageInternal
    Internal automatic reply message.

    .PARAMETER MessageExternal
    External automatic reply message.

    .PARAMETER CreateEvent
    If set to true, creates an out-of-office calendar event.

    .PARAMETER EventSubject
    Subject for the optional out-of-office calendar event.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Disable": {
                "DisplayName": "Enable or Disable Out-of-Office",
                "Select": {
                    "Options": [
                        {
                            "Display": "Enable Out-of-Office",
                            "ParameterValue": false,
                            "Customization": {
                                "Mandatory": [
                                    "Start",
                                    "MessageInternal",
                                    "MessageExternal"
                                ]
                            }
                        },
                        {
                            "Display": "Disable Out-of-Office",
                            "ParameterValue": true,
                            "Customization": {
                                "Hide": [
                                    "Start",
                                    "End",
                                    "MessageInternal",
                                    "MessageExternal",
                                    "CreateEvent",
                                    "EventSubject"
                                ]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "CallerName": {
                "Hide": true
            },
            "UserName": {
                "Hide": true
            },
            "Start": {
                "DisplayName": "Start Date"
            },
            "End": {
                "DisplayName": "End Date"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [bool] $Disable = $false,
    [System.DateTime] $Start = (get-date),
    [System.DateTime] $End = ((get-date) + (new-timespan -Days 3650)),
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Textarea } )]
    [string] $MessageInternal = "Sorry, this person is currently not able to receive your message.",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Textarea } )]
    [string] $MessageExternal = "Sorry, this person is currently not able to receive your message.",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Create calendar entry for the Out-Of-Office?" } )]
    [bool] $CreateEvent = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Clendar entry subject" } )]
    [string] $EventSubject = "Out of Office",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Configuring Out Of Office settings on mailbox '$UserName'."

$VerbosePreference = "SilentlyContinue"
try {
    Write-RjRbLog "Set Out Of Office settings initialized by '$CallerName' for '$UserName'"

    Connect-RjRbExchangeOnline

    if ($Disable) {
        "## Disabling Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled
        "## Be aware: If a calendar entry was created for the Out-Of-Office, it will not be removed."

    }
    else {
        "## Enabling Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled `
            -ExternalMessage $MessageExternal -InternalMessage $MessageInternal -StartTime $Start -EndTime $End -CreateOOFEvent $CreateEvent -OOFEventSubject $EventSubject
    }

    Write-RjRbLog "## Resulting MailboxAutoReplyConfiguration for user '$UserName': $(Get-MailboxAutoReplyConfiguration $UserName | Format-List | Out-String)"

    "## Successfully updated Out Of Office settings for user '$UserName'."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
