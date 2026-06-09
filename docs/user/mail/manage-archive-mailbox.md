# Manage Archive Mailbox

Manage the Exchange Online archive mailbox for a user

## Detailed description
Enables, disables, or retrieves the current status of the in-place archive mailbox for an Exchange Online user. Before any change the current state is verified so the script exits without making changes if the mailbox is already in the desired state. When enabling, any soft-deleted archive mailbox from within the last 30 days is automatically reconnected instead of creating a new one.

## Where to find
User \ Mail \ Manage Archive Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the user whose archive mailbox should be managed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
Action to perform: Enable, Disable, or GetStatus.

| Property | Value |
|----------|-------|
| Default Value | GetStatus |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

