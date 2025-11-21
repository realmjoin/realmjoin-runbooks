# Set Out Of Office

En-/Disable Out-of-office-notifications for a user/mailbox.

## Detailed description
En-/Disable Out-of-office-notifications for a user/mailbox.

## Where to find
User \ Mail \ Set Out Of Office

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online API
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -Disable

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -Start

| Property | Value |
|----------|-------|
| Default Value | (get-date) |
| Required | false |
| Type | DateTime |

### -End
10 years into the future ("forever") if left empty

| Property | Value |
|----------|-------|
| Default Value | ((get-date) + (new-timespan -Days 3650)) |
| Required | false |
| Type | DateTime |

### -MessageInternal

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### -MessageExternal

| Property | Value |
|----------|-------|
| Default Value | Sorry, this person is currently not able to receive your message. |
| Required | false |
| Type | String |

### -CreateEvent

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -EventSubject

| Property | Value |
|----------|-------|
| Default Value | Out of Office |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

