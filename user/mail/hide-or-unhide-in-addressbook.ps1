<#
    .SYNOPSIS
    Hide or unhide a mailbox in the address book

    .DESCRIPTION
    Hides or unhides a mailbox from the global address lists. Important: This change can take up to 72 hours until it is reflected in the global address list.

    .PARAMETER UserName
    User principal name of the mailbox.

    .PARAMETER HideMailbox
    If set to true, hides the mailbox from address lists.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "HideMailbox": {
                "DisplayName": "Hide the Mailbox",
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
                            "Display": "Hide the Mailbox in Address Book",
                            "Customization": {
                                "Default": {
                                    "HideMailbox": true
                                }
                            }
                        },
                        {
                            "Display": "Show the Mailbox in Address Book",
                            "Customization": {
                                "Default": {
                                    "HideMailbox": false
                                }
                            }
                        }
                    ]
                },
                "Default": "Hide the Mailbox in Address Book"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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

$Version = "1.0.0"
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