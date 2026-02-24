# Add Equipment Mailbox

Create an equipment mailbox

## Detailed description
Creates an Exchange Online equipment mailbox and optionally configures delegate access and calendar processing. If requested, the associated Entra ID user account is disabled after creation.

## Where to find
Org \ Mail \ Add Equipment Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### MailboxName
Alias (mail nickname) for the equipment mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Optional display name for the equipment mailbox.

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

