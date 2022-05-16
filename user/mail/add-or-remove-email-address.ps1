<#
  .SYNOPSIS
  Add/remove eMail address to/from mailbox.

  .DESCRIPTION
  Add/remove eMail address to/from mailbox, update primary eMail address.

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
                                "Display": "Add/Update eMail address",
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
                    "Default": "Add/Update eMail address"
                }
    ],
    "Parameters": {
        "UserName": {
            "Hide": true
        },
        "Remove": {
            "Default": false,
            "Hide": true
        },
        "CallerName": {
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
    [bool] $asPrimary = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

$VerbosePreference = "SilentlyContinue"

$outputString = "Trying to "
if ($Remove) {
    $outputString += "remove alias '$eMailAddress' from"
}
else {
    $outputString += "add alias '$eMailAddress' to"
}
$outputString += " user '$UserName'"
if ((-not $Remove) -and $asPrimary) {
    $outputString += " and setting it as primary"
}

$outputString

try {
    "## Trying to connect and check for $UserName"
    Connect-RjRbExchangeOnline

    # Get User / Mailbox
    $mailbox = Get-EXOMailbox -UserPrincipalName $UserName

    "## Current eMail Addresses"
    $mailbox.EmailAddresses

    ""
    if ($mailbox.EmailAddresses -icontains "smtp:$eMailAddress") {
        # eMail-Address is already present
        if ($Remove) {
            if ($eMailAddress -eq $mailbox.UserPrincipalName) {
                throw "Cannot remove the UserPrincipalName from the list of eMail-Addresses. Please rename the user for that."
            }
            $eMailAddressList = $mailbox.EmailAddresses | Where-Object { $_ -ne "smtp:$eMailAddress" }
            # Remove email address
            Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
            "## Alias $eMailAddress is removed from user $UserName"
            "## Waiting for Exchange to update the mailbox..."
            Start-Sleep -Seconds 30
        }
        else {
            if (-not $asPrimary) {
                "## $eMailAddress is already assigned to user $UserName"
            }
            else {
                "## Update primary address"
                $eMailAddressList = @($mailbox.EmailAddresses.toLower() | Where-Object { $_ -ne "smtp:$eMailAddress" })
                $eMailAddressList += "SMTP:$eMailAddress" 
                Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
                "## Successfully updated primary eMail address"
                ""
                "## Waiting for Exchange to update the mailbox..."
                Start-Sleep -Seconds 30
            }   
        }
    }
    else {
        # eMail-Address is not present
        if (-not $Remove) {
            # Add email address    
            if ($asPrimary) {
                $eMailAddressList = $mailbox.EmailAddresses.toLower() + "SMTP:$eMailAddress" 
                Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
            }
            else {
                Set-Mailbox -Identity $UserName -EmailAddresses @{add = "$eMailAddress" }
            }
            "## $eMailAddress successfully added to user $UserName"
            ""
            "## Waiting for Exchange to update the mailbox..."
            Start-Sleep -Seconds 30
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