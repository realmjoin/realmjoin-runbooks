<#
  .SYNOPSIS
  Grant another user sendAs permissions on this mailbox.

  .DESCRIPTION
  Grant another user sendAs permissions on this mailbox.

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
                "Select": {
                    "Options": [
                        {
                            "Display": "Delegate 'Send As'",
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
                                }
                            }
                        }
                    ]
                },
                "Default": "Delegate 'Send As'"
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
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "User '$userName' has no mailbox."
    }

    $trustee = Get-EXOMailbox -Identity $delegateTo -ErrorAction SilentlyContinue
    # Check if trustee has a mailbox
    if (-not $trustee) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "Trustee '$delegateTo' has no mailbox."
    }

    if ($Remove) {
        "## Trying to remove SendAs permission for mailbox '$UserName' from user '$($trustee.UserPrincipalName)'."
    }
    else {
        "## Trying to give SendAs permission for mailbox '$UserName' to user '$($trustee.UserPrincipalName)'."
    }
    
    if ($Remove) {
        Remove-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
        "## SendAs Permission for '$($trustee.UserPrincipalName)' removed from mailbox '$UserName'"
    }
    else {
        Add-RecipientPermission -Identity $UserName -Trustee $delegateTo -AccessRights SendAs -confirm:$false | Out-Null
        "## SendAs Permission for '$($trustee.UserPrincipalName)' added to mailbox '$UserName'"
    }

    ""
    "## Dump Recipient/Sender (SendAs) Permissions for '$UserName'"
    Get-RecipientPermission -Identity $UserName | Where-Object { ($_.Trustee -like '*@*') } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}