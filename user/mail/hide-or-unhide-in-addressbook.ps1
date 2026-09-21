<#
    .SYNOPSIS
    Hide this user's mailbox in the address book or show it

    .DESCRIPTION
    Hides the mailbox of this user from the global address list or shows it again. A hidden mailbox still receives email; it just does not appear when people browse the address book. The change can take up to 72 hours to show in the address list.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER HideMailbox
    Whether the mailbox is hidden or shown. Set by the "Action" choice.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "HideMailbox": {
                "DisplayName": "Hide the mailbox",
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Action",
                "Select": {
                    "Options": [
                        {
                            "Display": "Hide the mailbox in the address book",
                            "Customization": {
                                "Default": {
                                    "HideMailbox": true
                                }
                            }
                        },
                        {
                            "Display": "Show the mailbox in the address book",
                            "Customization": {
                                "Default": {
                                    "HideMailbox": false
                                }
                            }
                        }
                    ]
                },
                "Default": "Hide the mailbox in the address book"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [bool] $HideMailbox = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

if ($HideMailbox) {
    "## Trying to hide mailbox '$UserName' in addressbook."
}
else {
    "## Trying to show/unhide mailbox '$UserName' in addressbook."
}


try {
    Connect-RjRbExchangeOnline

    if ($HideMailbox) {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $true
        "## Mailbox '$UserName' is hidden."
    }
    else {
        Set-Mailbox -Identity $UserName -HiddenFromAddressListsEnabled $false
        "## Mailbox '$UserName' is not hidden."
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}