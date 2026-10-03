<#
    .SYNOPSIS
    Hide or show all Bookings calendars in the address book

    .DESCRIPTION
    Hides every Microsoft Bookings calendar mailbox from the global address list, or shows them again, on each run. New Bookings calendars are covered automatically the next time the runbook runs.

    .PARAMETER HideBookingCalendars
    Hidden calendars cannot be found in Outlook or the address book; turn off to list them again.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "HideBookingCalendars": {
                "DisplayName": "Hide Bookings calendars?"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [bool] $HideBookingCalendars = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.3"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbExchangeOnline

Get-Mailbox -RecipientTypeDetails SchedulingMailbox | ForEach-Object {
    # Address the mailbox by its SMTP address - the 'Identity' property holds the mailbox Name, which is
    # not unique in Exchange Online and can fail as an ambiguous identity.
    Set-Mailbox -HiddenFromAddressListsEnabled $HideBookingCalendars -Identity $_.PrimarySmtpAddress
    "## Updated Booking Calendar '$($_.Alias)' - hide in address book: '$HideBookingCalendars'."
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

