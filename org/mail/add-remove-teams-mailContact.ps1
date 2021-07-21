<#
  .SYNOPSIS
  Create/Remove a contact, to allow pretty email addresses for Teams channels.

  .DESCRIPTION
  Create/Remove a contact, to allow pretty email addresses for Teams channels.

  .PARAMETER RealAddress
  Enter the address created by MS Teams for a channel

  .PARAMETER DesiredAddress
  Will forward/relay to the real address.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Relay the desired address to the real address": false,
                    "Stop the relay and remove desired address": true
                }
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param
(
    [Parameter(Mandatory = $true)]    
    [ValidateScript( { Use-RJInterface -DisplayName "Real address" } )]
    [string] $RealAddress,
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -DisplayName "Desired address" } )]
    [string] $DesiredAddress,
    [ValidateScript( { Use-RJInterface -DisplayName "Name in Address Book" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this contact" } )]
    [bool] $Remove = $false
)

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