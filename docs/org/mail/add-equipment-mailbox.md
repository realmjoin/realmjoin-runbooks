# Add Equipment Mailbox

Create an equipment mailbox with optional booking delegates

## Detailed description
Creates an equipment mailbox in Exchange Online, for example for a projector or a pool car, so it can be booked in meeting requests. Without booking delegates the equipment accepts requests automatically when it is free. With booking delegates every request waits for their approval; they get no access to the mailbox itself. The user account behind the mailbox can be disabled.

## Where to find
Org \ Mail \ Add Equipment Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp
- **Type**: Microsoft Graph
  - User.ReadWrite.All *(optional: Disable user account)*

### RBAC roles
- Exchange Administrator


## Parameters
### MailboxName
Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Name shown in the address book. Leave empty to use the alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DelegateTo
Users who approve or decline every booking request for the equipment. Leave empty to accept requests automatically when the equipment is free.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String Array |

### DisableUser
Blocks sign-in for the user account behind the mailbox. Booking keeps working.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

