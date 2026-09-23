<#
    .SYNOPSIS
    Give a Teams channel a friendly email address or remove it

    .DESCRIPTION
    Creates a mail contact that forwards a friendly email address to the long address Teams generates for a channel. People can then email the channel with an address they can remember. The same runbook removes the friendly address again.

    .PARAMETER RealAddress
    Email address that Teams generated for the channel.

    .PARAMETER DesiredAddress
    Friendly address that should forward to the channel.

    .PARAMETER DisplayName
    Name shown for the contact in the address book. Leave empty to use the part of the friendly address before the @ sign.

    .PARAMETER Remove
    Set up the friendly address creates the mail contact; Remove the friendly address deletes it again.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "RealAddress": {
                "DisplayName": "Channel email address"
            },
            "DesiredAddress": {
                "DisplayName": "Friendly email address"
            },
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Set up the friendly address": false,
                    "Remove the friendly address": true
                }
            },
            "CallerName": {
                "Hide": true
            },
            "DisplayName": {
                "DisplayName": "Name in the address book"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $RealAddress,
    [Parameter(Mandatory = $true)]
    [string] $DesiredAddress,
    [string] $DisplayName,
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

$VerbosePreference = "SilentlyContinue"

try {
    Connect-RjRbExchangeOnline

    # Handle default teams formatting
    if ($RealAddress -match "<") {
        $RealAddress = $RealAddress.Split("<>")[1]
    }

    # Does a contact exist for this real address?
    $contact = Get-EXORecipient -Identity $RealAddress -ErrorAction SilentlyContinue
    if (-not $contact) {
        if ($Remove) {
            "## Contact does not exist. Nothing to do."
            exit
        }

        # Make sure we have a mailNickname and DisplayName
        $Nickname = ($DesiredAddress.Split('@'))[0]
        if (-not $DisplayName) {
            $DisplayName = $Nickname
        }
        # Create the contact
        $contact = New-MailContact -DisplayName $DisplayName -ExternalEmailAddress $RealAddress -name $Nickname
    }

    if ($contact.RecipientType -ne "MailContact") {
        throw "$RealAddress is in use - can not create a mailContact."
    }

    $neweMailAddresses = @()
    $contact.EmailAddresses | ForEach-Object {
        if ($_ -ne "smtp:$DesiredAddress") {
            $neweMailAddresses += $_
        }
    }
    if (-not $Remove) {
        $neweMailAddresses += "smtp:$DesiredAddress"
    }

    Set-MailContact -Identity $contact.Name -EmailAddresses $neweMailAddresses

    "## Successfully modified mailContact '$($contact.Name)'"

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}