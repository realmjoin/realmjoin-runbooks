<#
  .SYNOPSIS
  Turn this users mailbox into a shared mailbox.

  .DESCRIPTION
  Turn this users mailbox into a shared mailbox.

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
                            "Display": "Turn mailbox into shared mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                }
                            }
                        }, {
                            "Display": "turn shared mailbox back into regular mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": true
                                },
                                "Hide": [
                                    "AutoMapping",
                                    "delegateTo"
                                ]
                            }
                        }
                    ]
                },
                "Default": "Turn mailbox into shared mailbox"
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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox"} )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Turn mailbox back to regular mailbox" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)


try {
    "## Trying to connect and check for $UserName"
    Connect-RjRbExchangeOnline
    "## connected"

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User $UserName has no mailbox."
    }

    "## Current Permission Delegations"
    Get-MailboxPermission -Identity $UserName | Select-Object -expandproperty User

    ""

    if ($Remove) {
        # Remove access
        $PermittedUsers = Get-MailboxPermission -Identity $UserName | Where-Object { $_.User -ne "NT AUTHORITY\SELF" }
        foreach($PermittedUser in $PermittedUsers){
            Remove-MailboxPermission -Identity $UserName -User $PermittedUser.User -AccessRights $PermittedUser.AccessRights -InheritanceType All -confirm:$false | Out-Null
            "## Mailbox Access Permission for $($PermittedUser.User) reverted from mailbox $UserName"
        }
        $PermittedRecipients = Get-RecipientPermission -Identity $UserName | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
        foreach($PermittedRecipient in $PermittedRecipients){
            Remove-RecipientPermission -Identity $UserName -Trustee $PermittedRecipient.Trustee -AccessRights $PermittedRecipient.AccessRights -confirm:$false | Out-Null
            "## SendAs/SendOnBehalf Permission for $($PermittedRecipient.Trustee) reverted from mailbox $UserName"
        }
    
        Set-Mailbox $UserName -Type regular -GrantSendOnBehalfTo $null
        "## Mailbox $UserName turned into regular Mailbox"
    }
    else {
        Set-Mailbox $UserName -Type shared
        "## Turned mailbox $UserName into shared mailbox"
        # Add access
        if($delegateTo){
        Add-MailboxPermission  $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        "## FullAccess Permission for $delegateTo added to mailbox $UserName"
        }
        
    }

    ""
    "## Dump Mailbox Permission Details"
    Get-MailboxPermission -Identity $UserName
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}
