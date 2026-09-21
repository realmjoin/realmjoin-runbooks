<#
    .SYNOPSIS
    Add an email address to this user's mailbox or remove one

    .DESCRIPTION
    Adds an alias address to the mailbox of this user or removes one. A new or existing address can also be made the primary address that outgoing mail is sent from.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER EmailAddress
    Address to add or remove, for example jane.doe@contoso.com.

    .PARAMETER Remove
    Whether the address is removed instead of added. Set by the "Action" choice.

    .PARAMETER asPrimary
    Makes this address the primary one that outgoing mail is sent from.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "ParameterList": [
            {
                "DisplayBefore": "asPrimary",
                "DisplayName": "Action",
                "Select": {
                    "Options": [
                        {
                            "Display": "Add or update the address",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                }
                            }
                        },
                        {
                            "Display": "Remove the address",
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
                "Default": "Add or update the address"
            }
        ],
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Remove this address",
                "Default": false,
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "EmailAddress": {
                "DisplayName": "Email address"
            },
            "asPrimary": {
                "DisplayName": "Set as primary address?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $EmailAddress,
    [bool] $Remove = $false,
    [bool] $asPrimary = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

$VerbosePreference = "SilentlyContinue"

$outputString = "Trying to "
if ($Remove) {
    $outputString += "remove alias '$EmailAddress' from"
}
else {
    $outputString += "add alias '$EmailAddress' to"
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

    "## Current Email Addresses"
    $mailbox.EmailAddresses

    ""
    if ($mailbox.EmailAddresses -icontains "smtp:$EmailAddress") {
        # eMail-Address is already present
        if ($Remove) {
            if ($EmailAddress -eq $mailbox.UserPrincipalName) {
                throw "Cannot remove the UserPrincipalName from the list of eMail-Addresses. Please rename the user for that."
            }
            $eMailAddressList = [array]($mailbox.EmailAddresses | Where-Object { $_ -ne "smtp:$EmailAddress" })
            # Remove email address
            Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
            "## Alias $EmailAddress is removed from user $UserName"
            "## Waiting for Exchange to update the mailbox..."
            Start-Sleep -Seconds 30
        }
        else {
            if (-not $asPrimary) {
                "## $EmailAddress is already assigned to user $UserName"
            }
            else {
                "## Update primary address"
                [array]$eMailAddressList = [array]($mailbox.EmailAddresses.toLower() | Where-Object { $_ -ne "smtp:$EmailAddress" }) + [array]("SMTP:$EmailAddress")
                #$eMailAddressList += "SMTP:$EmailAddress"
                Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
                "## Successfully updated primary Email address"
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
                [array]$eMailAddressList = [array]($mailbox.EmailAddresses.toLower()) + [array]("SMTP:$EmailAddress")
                Set-Mailbox -Identity $UserName -EmailAddresses $eMailAddressList
            }
            else {
                Set-Mailbox -Identity $UserName -EmailAddresses @{add = "$EmailAddress" }
            }
            "## $EmailAddress successfully added to user $UserName"
            ""
            "## Waiting for Exchange to update the mailbox..."
            Start-Sleep -Seconds 30
        }
        else {
            "## $EmailAddress is not assigned to user $UserName"
        }
    }

    ""
    "## Dump Mailbox Details"
    Get-EXOMailbox -UserPrincipalName $UserName

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}