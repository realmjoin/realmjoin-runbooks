<#
  .SYNOPSIS
  Grant another user full access to this mailbox.

  .DESCRIPTION
  Grant another user full access to this mailbox.

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
            "Remove": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "AutoMapping",
                "Select": {
                    "Options": [
                        {
                            "Display": "Delegate 'Full Access'",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                }
                            }
                        }, {
                            "Display": "Remove this delegation",
                            "Customization": {
                                "Default": {
                                    "Remove": true
                                },
                                "Hide": [
                                    "AutoMapping"
                                ]
                            }
                        }
                    ]
                },
                "Default": "Delegate 'Full Access'"
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox"} )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false

)


try {
    "## Trying to connect and check for $UserName"
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User $userName has no mailbox."
    }

    "## Current Permission Delegations"
    Get-MailboxPermission -Identity $UserName | Select-Object -expandproperty User

    ""
    if ($Remove) {
        # Remove access
        Remove-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -confirm:$false | Out-Null
        "## FullAccess Permission for $delegateTo removed from mailbox $UserName"
    }
    else {
        # Add access
        Add-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        "## FullAccess Permission for $delegateTo added to mailbox $UserName"
    }

    ""
    "## Dump Mailbox Permission Details"
    Get-MailboxPermission -Identity $UserName
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}