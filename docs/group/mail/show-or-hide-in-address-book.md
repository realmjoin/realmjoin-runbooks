# Show Or Hide In Address Book

Show or hide this group in the address book

## Detailed description
Shows this Microsoft 365 or distribution group in the address lists or hides it from them. A hidden group still receives email at its address; it just does not appear in the address book. Query only shows the current state without changing anything.

## Where to find
Group \ Mail \ Show Or Hide In Address Book

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### GroupName
Identity of the group in Exchange Online, such as its name or alias. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
Show lists the group in the address book, Hide removes it from the lists, Query only shows the current state.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

