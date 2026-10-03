# Hide Or Unhide In Addressbook

Hide this user's mailbox in the address book or show it

## Detailed description
Hides the mailbox of this user from the global address list or shows it again. A hidden mailbox still receives email; it just does not appear when people browse the address book. The change can take up to 72 hours to show in the address list.

## Where to find
User \ Mail \ Hide Or Unhide In Addressbook

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### HideMailbox
Whether the mailbox is hidden or shown. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

