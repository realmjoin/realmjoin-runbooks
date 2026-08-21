# Set Out Of Office

Enable or disable mailbox out-of-office notifications

## Detailed description
Configures automatic replies for a mailbox and can optionally create an out-of-office calendar event. The runbook can either enable scheduled replies with internal and external messages or disable existing out-of-office settings.

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
User principal name of the mailbox. This value is auto-filled by the portal.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Disable
Select whether to enable out-of-office notifications or disable existing out-of-office settings.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Start
Start time for scheduled out-of-office replies.

| Property | Value |
|----------|-------|
| Default Value | (Get-Date) |
| Required | false |
| Type | DateTime |

### End
End time for scheduled out-of-office replies. If not specified, it defaults to 10 years from the current date.

| Property | Value |
|----------|-------|
| Default Value | ((Get-Date) + (New-TimeSpan -Days 3650)) |
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

### ExternalAudience
Controls who receives external automatic replies. Use None to send no external replies, Known to send replies only to known external contacts, or All to send replies to all external senders.

| Property | Value |
|----------|-------|
| Default Value | All |
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

