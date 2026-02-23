# Offboard User Temporarily

Temporarily offboard a user

## Detailed description
Temporarily offboards a user for scenarios such as parental leave or sabbatical by disabling access, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required.

## Where to find
User \ General \ Offboard User Temporarily

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All

### Permission notes
Azure IaaS: Contributor access on subscription or resource group used for the export

### RBAC roles
- User administrator


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RevokeAccess
If set to true, revokes the user's refresh tokens and active sessions.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DisableUser
If set to true, disables the user account for sign-in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportResourceGroupName
Azure Resource Group name for exporting data to storage.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### exportStorAccountName
Azure Storage Account name for exporting data to storage.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### exportStorAccountLocation
Azure region used when creating the Storage Account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### exportStorAccountSKU
SKU name used when creating the Storage Account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### exportStorContainerGroupMembershipExports
Container name used for group membership exports.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### exportGroupMemberships
If set to true, exports the user's current group memberships to Azure Storage.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ChangeLicensesSelector
Controls how directly assigned licenses should be handled.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### ChangeGroupsSelector
Controls how assigned groups should be handled. "Change" and "Remove all" will both honour "groupToAdd".

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### GroupToAdd
Group that should be added or kept when group changes are enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsToRemovePrefix
Prefix used to remove groups matching a naming convention.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RevokeGroupOwnership
If set to true, removes or replaces the user's group ownerships.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ReplacementOwnerName
Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

