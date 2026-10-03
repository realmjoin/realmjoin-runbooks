# Set Out Of Office

Set or remove automatic replies for this user

## Detailed description
Turns on automatic replies for the mailbox of this user, with separate messages for people inside and outside the organization and for a period you choose. A matching out-of-office entry can be added to the calendar. Existing automatic replies can also be switched off again; a calendar entry created earlier is not removed.

## Where to find
User \ Mail \ Set Out Of Office

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the mailbox the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Disable
Enable automatic replies turns them on for the period and messages below. Disable switches existing automatic replies off.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Start
When the automatic replies begin.

| Property | Value |
|----------|-------|
| Default Value | (Get-Date) |
| Required | false |
| Type | DateTime |

### End
When the automatic replies stop.

| Property | Value |
|----------|-------|
| Default Value | ((Get-Date) + (New-TimeSpan -Days 3650)) |
| Required | false |
| Type | DateTime |

### MessageInternal
Reply sent to people inside the organization.

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### MessageExternal
Reply sent to people outside the organization.

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### ExternalAudience
None sends no external replies, Known only to saved contacts, All to every external sender.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### CreateEvent
Puts a matching out-of-office entry into the user's calendar for the same period.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EventSubject
Subject of the out-of-office entry as colleagues see it in the calendar.

| Property | Value |
|----------|-------|
| Default Value | Out of Office |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

