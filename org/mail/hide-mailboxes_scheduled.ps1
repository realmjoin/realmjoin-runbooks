<#
    .SYNOPSIS
    Hide or unhide special mailboxes in the Global Address List

    .DESCRIPTION
    Hides or unhides special mailboxes in the Global Address List, currently intended for Bookings calendars. The runbook updates all scheduling mailboxes accordingly.

    .PARAMETER HideBookingCalendars
    If set to true, booking calendars are hidden from address lists.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [bool] $HideBookingCalendars = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbExchangeOnline

Get-Mailbox -RecipientTypeDetails SchedulingMailbox | ForEach-Object {
    Set-Mailbox -HiddenFromAddressListsEnabled $HideBookingCalendars -Identity $_.Identity
    "## Updated Booking Calendar '$($_.Alias)' - hide in address book: '$HideBookingCalendars'."
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

