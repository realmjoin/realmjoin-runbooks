<#
  .SYNOPSIS
  Grant another user sendOnBehalf permissions on this mailbox.

  .DESCRIPTION
  Grant another user sendOnBehalf permissions on this mailbox.

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
                            "Display": "Delegate 'Send On Behalf Of'",
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
                "Default": "Delegate 'Send On Behalf Of'"
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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User  -DisplayName "User/Mailbox" } )]
    [Parameter(Mandatory = $true)] [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [Parameter(Mandatory = $true)] [string] $delegateTo,
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