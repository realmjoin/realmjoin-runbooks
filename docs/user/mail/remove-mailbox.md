# Remove Mailbox

Permanently delete this shared mailbox, room or Bookings calendar

## Detailed description
Deletes this shared mailbox, room mailbox or Bookings calendar for good. Before deleting, the runbook checks that the mailbox really is one of these types; regular user mailboxes are refused. The mailbox and its content are not recoverable afterwards.

## Where to find
User \ Mail \ Remove Mailbox

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


[Back to Table of Content](../../../README.md)

