<#
  .SYNOPSIS
  Add/remove eMail address to/from mailbox.

  .DESCRIPTION
  Add/remove eMail address to/from mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
    "ParameterList": [
        {
                    "DisplayBefore": "asPrimary",
                    "Select": {
                        "Options": [
                            {
                                "Display": "Add eMail address",
                                "Customization": {
                                    "Default": {
                                        "Remove": false
                                    }
                                }
                            },
                            {
                                "Display": "Remove this address",
                                "Customization": {
                                    "Default": {
                                        "Remove": true
                                    },
                                    "Hide": [
                                        "asPrimary"
                                    ]
                                }
                            }
                        ]
                        
                    },
                    "Default": "Add eMail address"
                }
    ],
    "Parameters": {
        "UserName": {
            "Hide": true
        },
        "Remove": {
            "Default": false,
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -DisplayName "eMail Address" } )]
    [string] $eMailAddress,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this address" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Set as primary address" } )]
    [bool] $asPrimary = $false
)

$VerbosePreference = "SilentlyContinue"

try {
    "## Trying to connect and check for $UserName"
    Connect-RjRbExchangeOnline

    # Get User / Mailbox
    $mailbox = Get-EXOMailbox -UserPrincipalName $UserName

    "## Current eMail Addresses"
    Get-EXOMailbox -UserPrincipalName $UserName | Select-Object -expandproperty EmailAddresses

    ""
    if ($mailbox.EmailAddresses -icontains "smtp:$eMailAddress") {
        # eMail-Address is already present
        if ($Remove) {
            # Remove email address
            Set-Mailbox -Identity $UserName -EmailAddresses @{remove = "$eMailAddress" }
            "## Alias $eMailAddress is removed from user $UserName"
        }
        else {
            "## $eMailAddress is already assigned to user $UserName"
        }
    } 
    else {
        # eMail-Address is not present
        if (-not $Remove) {
            # Add email address    
            if ($asPrimary) {
                Set-Mailbox -Identity $UserName -EmailAddresses @{add = "SMTP:$eMailAddress" }
            }
            else {
                Set-Mailbox -Identity $UserName -EmailAddresses @{add = "$eMailAddress" }
            }
            "## $eMailAddress successfully added to user $UserName"
        }
        else {
            "## $eMailAddress is not assigned to user $UserName"
        }
    }

    ""
    "## Dump Mailbox Details"
    Get-EXOMailbox -UserPrincipalName $UserName

}
finally {   
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}