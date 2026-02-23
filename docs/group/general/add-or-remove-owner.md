# Add Or Remove Owner

Add or remove a Office 365 group owner

## Detailed description
This runbook adds a user as an owner of a group or removes an existing owner.
For Microsoft 365 groups, it also ensures that newly added owners are members of the group.
Use the Remove switch to remove ownership instead of adding it.

## Where to find
Group \ General \ Add Or Remove Owner

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### GroupID
Object ID of the target group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserId
Object ID of the user to add or remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
"Add User as Owner" (final value: $false) or "Remove User as Owner" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the user from the group owners. If set to false, it will add the user as an owner of the group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

