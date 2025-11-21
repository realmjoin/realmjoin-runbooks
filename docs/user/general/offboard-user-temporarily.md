# Offboard User Temporarily

Temporarily offboard a user.

## Detailed description
Temporarily offboard a user in cases like parental leaves or sabaticals.

## Where to find
User \ General \ Offboard User Temporarily

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All
  - Directory.ReadWrite.All

### Permission notes
Azure IaaS: Contributor access on subscription or resource group used for the export

### RBAC roles
- User administrator


## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -RevokeAccess

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -DisableUser

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -exportResourceGroupName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -exportStorAccountName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -exportStorAccountLocation

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -exportStorAccountSKU

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -exportStorContainerGroupMembershipExports

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -exportGroupMemberships

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -ChangeLicensesSelector

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### -ChangeGroupsSelector
"Change" and "Remove all" will both honour "groupToAdd"

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### -GroupToAdd

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -GroupsToRemovePrefix

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -RevokeGroupOwnership

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -ReplacementOwnerName
Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

