<#
  .SYNOPSIS
  En-/Disable Out-of-office-notifications for a user/mailbox.

  .DESCRIPTION
  En-/Disable Out-of-office-notifications for a user/mailbox.

  .PARAMETER End
  10 years into the future ("forever") if left empty

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

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
            "CallerName": {
                "Hide": true
            },
            "Start": {
                "DisplayName": "Start Date"
            },
            "End": {
                "DisplayName": "End Date"
            },
            
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, ExchangeOnlineManagement

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
