<#
  .SYNOPSIS
  Hide / Unhide special mailboxes in Global Address Book

  .DESCRIPTION
  Hide / Unhide special mailboxes in Global Address Book. Currently intended for Booking calendars.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }, Az.Storage, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [bool] $HideBookingCalendars = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbExchangeOnline

Get-Mailbox -RecipientTypeDetails SchedulingMailbox | ForEach-Object {
    Set-Mailbox -HiddenFromAddressListsEnabled $HideBookingCalendars -Identity $_.Identity
    "## Updated Booking Calendar '$($_.Alias)' - hide in address book: '$HideBookingCalendars'."
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

