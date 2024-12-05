<#
  .SYNOPSIS
  (Un)Hide this mailbox in address book.

  .DESCRIPTION
  (Un)Hide this mailbox in address book.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "HideMailbox": {
                "DisplayName": "Hide the Mailbox",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, ExchangeOnlineManagement

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