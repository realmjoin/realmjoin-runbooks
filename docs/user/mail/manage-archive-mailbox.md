# Manage Archive Mailbox

Enable, disable or check the archive mailbox of this user

## Detailed description
Enables or disables the in-place archive mailbox of this user, or shows its current status. Nothing changes when the mailbox is already in the requested state. When enabling, an archive that was disabled within the last 30 days is reconnected instead of creating a new one.

## Where to find
User \ Mail \ Manage Archive Mailbox

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

### Action
Whether the archive is enabled, disabled or only its status shown. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | GetStatus |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

