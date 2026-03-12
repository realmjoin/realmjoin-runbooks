# Add Room Mailbox

Create a room mailbox resource

## Detailed description
Creates an Exchange Online room mailbox and optionally configures delegation and calendar processing. If requested, the associated Entra ID user account is disabled after creation.

## Where to find
Org \ Mail \ Add Room Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### MailboxName
Alias (mail nickname) for the room mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Optional display name for the room mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DelegateTo
Optional user who receives delegated access to the mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Capacity
Optional room capacity in number of people.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### AutoAccept
If set to true, meeting requests are automatically accepted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AutoMapping
If set to true, the mailbox is automatically mapped in Outlook for the delegate.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DisableUser
If set to true, the associated Entra ID user account is disabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

