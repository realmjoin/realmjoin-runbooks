# Assign Or Unassign License

Assign or remove a license for this user via a license group

## Detailed description
Adds this user to a license assignment group or removes the user from it, which assigns or removes the license the group carries.

## Where to find
User \ General \ Assign Or Unassign License

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupID_License
Group that carries the license. Only groups whose name starts with LIC_ are offered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Assign adds the user to the group. Remove takes the user out of it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

