# Hide Mailboxes (Scheduled)

Hide or show all Bookings calendars in the address book

## Detailed description
Hides every Microsoft Bookings calendar mailbox from the global address list, or shows them again, on each run. New Bookings calendars are covered automatically the next time the runbook runs.

## Where to find
Org \ Mail \ Hide Mailboxes_Scheduled

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### HideBookingCalendars
Hidden calendars cannot be found in Outlook or the address book; turn off to list them again.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | true |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

