# Add Equipment Mailbox

Create an equipment mailbox with optional delegate

## Detailed description
Creates an equipment mailbox in Exchange Online, for example for a projector or a pool car, so it can be booked in meeting requests. A delegate can get full access and manage the bookings, and meeting requests can be accepted automatically. The user account behind the mailbox can be disabled so nobody signs in with it.

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
User who gets full access to the mailbox and handles its booking requests. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AutoAccept
Meeting requests are accepted automatically when the equipment is free.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AutoMapping
The mailbox opens automatically in the delegate's Outlook.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DisableUser
Blocks sign-in for the user account behind the mailbox. Booking keeps working.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

