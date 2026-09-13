# Offboard User Permanently

Permanently offboard a user

## Detailed description
Permanently offboards a user by revoking access, disabling or deleting the account, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required and replaces the user as manager of direct reports and as sponsor of (guest) users.

## Where to find
User \ General \ Offboard User Permanently

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when exportGroupMemberships is used)

### RBAC roles
- User Administrator
- Exchange Administrator


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserTypeSelector
Controls which user types this runbook may be run against: all users, member users only or guest users only. The run aborts before any change if the selected user does not match. To enforce the restriction, configure it as a tenant setting and hide the parameter via RunbookCustomization - otherwise operators can change it in the runbook form.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

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

### exportGroupMemberships
If set to true, exports the user's current group memberships to an Azure Storage Account and returns a time-limited download link.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the group membership export.

| Property | Value |
|----------|-------|
| Default Value | user-leaver-groupmemberships |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for the upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days until the generated download link expires.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |

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

### ReplaceManagerReferences
If set to true, all direct reports of the offboarded user get the replacement person assigned as their new manager. Without a resolvable replacement, affected users are only listed for manual follow-up.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ReplaceSponsorReferences
If set to true, the offboarded user is replaced by the replacement person wherever they are set as sponsor (typically on guest users). Without a resolvable replacement, affected users are only listed for manual follow-up. Sponsorships that the user only holds through a group membership are left untouched, as they remain valid after the offboarding. As Graph offers no reverse lookup for sponsors, this option scans all users of the tenant.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

