# Offboard User Permanently

Permanently offboard a user

## Detailed description
Permanently offboards a user by revoking access, disabling or deleting the account, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required.

## Where to find
User \ General \ Offboard User Permanently

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

### DeleteUser
"Delete user object" (final value: $true) or "Keep the user object" (final value: $false) can be selected as action to perform. If set to true, the user object will be deleted. If set to false, the user object will be kept but access will be revoked and sign-in will be blocked.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DisableUser
If set to true, disables the user account for sign-in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### RevokeAccess
If set to true, revokes the user's refresh tokens and active sessions.

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
"Change" and "Remove all" will both honour "groupToAdd"

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
"Remove/Replace this user's group ownerships" (final value: $true) or "User will remain owner / Do not change" (final value: $false) can be selected as action to perform. If set to true, the runbook will attempt to remove the user from group ownerships. If the user is the last owner of a group, it will attempt to assign a replacement owner; if that fails, it will skip ownership change for that group and log it for manual follow-up.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ManagerAsReplacementOwner
If set to true, uses the user's manager as replacement owner where applicable.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ReplacementOwnerName
User who will take over group or resource ownership if required.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

