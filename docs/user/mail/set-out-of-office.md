# Set Out Of Office

Enable or disable out-of-office notifications for a mailbox

## Detailed description
Configures automatic replies for a mailbox and optionally creates an out-of-office calendar event. The runbook can either enable scheduled replies or disable them.

## Where to find
User \ Mail \ Set Out Of Office

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Disable
"Enable Out-of-Office" (final value: $false) or "Disable Out-of-Office" (final value: $true) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Start
Start time for scheduled out-of-office replies.

| Property | Value |
|----------|-------|
| Default Value | (get-date) |
| Required | false |
| Type | DateTime |

### End
End time for scheduled out-of-office replies. If not specified, defaults to 10 years from the current date.

| Property | Value |
|----------|-------|
| Default Value | ((get-date) + (new-timespan -Days 3650)) |
| Required | false |
| Type | DateTime |

### MessageInternal
Internal automatic reply message.

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### MessageExternal
External automatic reply message.

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### CreateEvent
If set to true, creates an out-of-office calendar event.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EventSubject
Subject for the optional out-of-office calendar event.

| Property | Value |
|----------|-------|
| Default Value | Out of Office |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

