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
                                    "MessageExternal"
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
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Enable or Disable Out-of-Office" } )]
    [bool] $Disable = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Start Date" } )]
    [System.DateTime] $Start = (get-date),
    [ValidateScript( { Use-RJInterface -DisplayName "End Date" } )]
    [System.DateTime] $End = ((get-date) + (new-timespan -Days 3650)),
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string] $MessageInternal = "Sorry, this person is currently not able to receive your message.",
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string] $MessageExternal = "Sorry, this person is currently not able to receive your message.",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

"## Configuring Out Of Office settings on mailbox '$UserName'."

$VerbosePreference = "SilentlyContinue"
try {
    Write-RjRbLog "Set Out Of Office settings initialized by '$CallerName' for '$UserName'"

    Connect-RjRbExchangeOnline

    if ($Disable) {
        Write-RjRbLog "Disable Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled
    }
    else {
        Write-RjRbLog "Enabling Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled `
            -ExternalMessage $MessageExternal -InternalMessage $MessageInternal -StartTime $Start -EndTime $End
    }

    Write-RjRbLog "## Resulting MailboxAutoReplyConfiguration for user '$UserName': $(Get-MailboxAutoReplyConfiguration $UserName | Format-List | Out-String)"

    "## Successfully updated Out Of Office settings for user '$UserName'."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null    
}
