# Add Or Remove Nested Group

Add/remove a nested group to/from a group

## Detailed description
This runbook adds a nested group to a target group or removes an existing nesting.
It supports Microsoft Entra ID groups and Exchange Online distribution or mail-enabled security groups.
Use the Remove switch to remove the nested group instead of adding it.

## Where to find
Group \ General \ Add Or Remove Nested Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All


## Parameters
### GroupID
Object ID of the target group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NestedGroupID
Object ID of the group to add as a nested member.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Set to true to remove the nested group membership, or false to add it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

