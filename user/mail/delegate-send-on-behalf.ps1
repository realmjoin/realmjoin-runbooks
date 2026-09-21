<#
    .SYNOPSIS
    Grant or remove Send on Behalf permission on this user's mailbox

    .DESCRIPTION
    Lets another person send email on behalf of this user, so recipients see the delegate's name with "on behalf of" this user, or removes that permission again. The resulting list of trustees is shown after the change.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER delegateTo
    Person who gets or loses the Send on Behalf permission.

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
                            "Display": "Grant Send on Behalf",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                }
                            }
                        },
                        {
                            "Display": "Remove Send on Behalf",
                            "Customization": {
                                "Default": {
                                    "Remove": true
                                }
                            }
                        }
                    ]
                },
                "Default": "Grant Send on Behalf"
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User  -DisplayName "User/Mailbox" } )]
    [Parameter(Mandatory = $true)] [string] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [Parameter(Mandatory = $true)] [string] $delegateTo,
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
        throw "User '$UserName' has no mailbox."
    }

    $trustee = Get-EXOMailbox -Identity $delegateTo -ErrorAction SilentlyContinue
    # Check if trustee has a mailbox
    if (-not $trustee) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw "Trustee '$delegateTo' has no mailbox."
    }

    if ($Remove) {
        "## Trying to remove SendOnBehalf permission for mailbox '$UserName' from user '$($trustee.UserPrincipalName)'."
    }
    else {
        "## Trying to give SendOnBehalf permission for mailbox '$UserName' to user '$($trustee.UserPrincipalName)'."
    }

    if ($Remove) {
        #Remove permission
        Set-Mailbox -Identity $UserName -GrantSendOnBehalfTo @{Remove = "$delegateTo" } -Confirm:$false | Out-Null
        "## SendOnBehalf Permission for '$($trustee.UserPrincipalName)' removed from mailbox '$($user.UserPrincipalName)'"
    }
    else {
        #Add permission
        Set-Mailbox -Identity $UserName -GrantSendOnBehalfTo @{Add = "$delegateTo" } -Confirm:$false | Out-Null
        "## SendOnBehalf Permission for '$($trustee.UserPrincipalName)' added to mailbox '$($user.UserPrincipalName)'"
    }

    ""
    "## Dump SendOnBehalf Permissions for '$UserName'"
    (Get-Mailbox -Identity $UserName).GrantSendOnBehalfTo | ForEach-Object {
        $sobTrustee = Get-EXOMailbox -Identity $_
        $result = @{}
        $result.Identity = $user.Identity
        $result.Trustee = $sobTrustee.UserPrincipalName
        $result.AccessRights = "{SendOnBehalf}"
        [PsCustomObject]$result
    } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}