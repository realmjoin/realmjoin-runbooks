# Assign Or Unassign License

Assign or remove a license for a user via group membership

## Detailed description
Adds or removes a user to a dedicated license assignment group to control license allocation. The license group must match the configured naming convention.

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
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupID_License
Object ID of the license assignment group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
"Assign the license to the user" (final value: $false) or "Remove the license from the user" (final value: $true) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

