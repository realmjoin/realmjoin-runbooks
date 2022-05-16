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
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

try {
    "## Connecting ..."
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User '$UserName' has no mailbox."
    }

    $trustee = Get-EXOMailbox -Identity $delegateTo -ErrorAction SilentlyContinue
    # Check if trustee has a mailbox
    if (-not $trustee) {
        throw "Trustee '$delegateTo' has no mailbox."
    }
    
    if ($Remove) {
        "## Trying to remove full access to mailbox '$UserName' from user '$($trustee.UserPrincipalName)'."
    }
    else {
        "## Trying to give full access to mailbox '$UserName' to user '$($trustee.UserPrincipalName)'."
    }
    
    if ((-not $Remove) -and $AutoMapping) {
        "## Mailbox will automatically appear in Outlook."
    }
    
    "## Current Mailbox Access Permissions for '$UserName'"
    Get-MailboxPermission -Identity $UserName | Where-Object { ($_.user -like '*@*') } | Format-Table -Property Identity, User, AccessRights -AutoSize | Out-String

    ""
    if ($Remove) {
        # Remove access
        Remove-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -confirm:$false | Out-Null
        "## FullAccess Permission for '$($trustee.UserPrincipalName)' removed from mailbox '$UserName'"
    }
    else {
        # Add access
        Add-MailboxPermission -Identity $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        "## FullAccess Permission for '$($trustee.UserPrincipalName)' added to mailbox '$UserName'"
    }

    ""
    "## New Mailbox Access Permissions for '$UserName'"
    Get-MailboxPermission -Identity $UserName | Where-Object { ($_.user -like '*@*') } | Format-Table -Property Identity, User, AccessRights -AutoSize | Out-String
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}