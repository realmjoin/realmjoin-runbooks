# Add Room Mailbox

Create a room mailbox with optional booking delegates

## Detailed description
Creates a room mailbox in Exchange Online so the room can be booked in meeting requests. Without booking delegates the room accepts requests automatically when it is free. With booking delegates every request waits for their approval; they get no access to the mailbox itself. The user account behind the mailbox can be disabled so nobody signs in with it.

## Where to find
Org \ Mail \ Add Room Mailbox

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
Name shown in the address book and the room finder. Leave empty to use the alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DelegateTo
Users who approve or decline every booking request for the room. Leave empty to accept requests automatically when the room is free.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String Array |

### Capacity
How many people fit in the room. Shown in the room finder. Leave at 0 to set no capacity.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### DisableUser
Blocks sign-in for the user account behind the mailbox. Booking keeps working.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

