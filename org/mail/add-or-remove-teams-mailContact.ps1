<#
    .SYNOPSIS
    Create/Remove a contact, to allow pretty email addresses for Teams channels.

    .DESCRIPTION
    Creates or updates a mail contact so a desired email address relays to the real Teams channel email address. The runbook can also remove the desired relay address again.

    .PARAMETER RealAddress
    Enter the address created by MS Teams for a channel

    .PARAMETER DesiredAddress
    Desired email address that should relay to the real address.

    .PARAMETER DisplayName
    Optional display name for the contact in the address book.

    .PARAMETER Remove
    "Relay the desired address to the real address" (final value: $false) or "Stop the relay and remove desired address" (final value: $true) can be selected as action to perform.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Relay the desired address to the real address": false,
                    "Stop the relay and remove desired address": true
                }
            },
            "CallerName": {
                "Hide": true
            },
            "DisplayName": {
                "DisplayName": "Name in Address Book"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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

$Version = "1.0.0"
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