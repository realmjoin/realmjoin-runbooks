<#
    .SYNOPSIS
    Grant or remove Send As permission on this user's mailbox

    .DESCRIPTION
    Lets another person send email as this user, so messages appear to come from this mailbox, or removes that permission again. The permissions are shown before and after the change.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER delegateTo
    Person who gets or loses the Send As permission.

    .PARAMETER Remove
    Whether the permission is removed instead of granted. Set by the "Action" choice.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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
                "Select": {
                    "Options": [
                        {
                            "Display": "Grant Send As",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                }
                            }
                        },
                        {
                            "Display": "Remove Send As",
                            "Customization": {
                                "Default": {
                                    "Remove": true
                                }
                            }
                        }
                    ]
                },
                "Default": "Grant Send As"
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Remove this delegation" } )]
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

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