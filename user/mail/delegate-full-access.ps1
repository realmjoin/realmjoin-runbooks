<#
    .SYNOPSIS
    Delegate FullAccess permissions to another user on a mailbox or remove existing delegation

    .DESCRIPTION
    Grants or removes FullAccess permissions for a delegate on a mailbox. Optionally enables Outlook automapping when granting access.
    Also shows the current and new permissions for the mailbox.
    Automapping allows the delegated mailbox to automatically appear in the delegate's Outlook client.

    .PARAMETER UserName
    User principal name of the mailbox.

    .PARAMETER delegateTo
    User principal name of the delegate.

    .PARAMETER Remove
    If set to true, removes the delegation instead of granting it.

    .PARAMETER AutoMapping
    If set to true, enables Outlook automapping when granting FullAccess.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "Hide": true
            },
            "CallerName": {
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
                        },
                        {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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