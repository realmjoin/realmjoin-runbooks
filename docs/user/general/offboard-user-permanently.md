# Offboard User Permanently

## Permanently offboard a user.

## Description
Permanently offboard a user.

## Where to find
User \ General \ Offboard User Permanently

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
Description: 
Default Value: 
Required: true

### -DeleteUser
Description: 
Default Value: False
Required: false

### -DisableUser
Description: 
Default Value: True
Required: false

### -RevokeAccess
Description: 
Default Value: True
Required: false

### -exportResourceGroupName
Description: 
Default Value: 
Required: false

### -exportStorAccountName
Description: 
Default Value: 
Required: false

### -exportStorAccountLocation
Description: 
Default Value: 
Required: false

### -exportStorAccountSKU
Description: 
Default Value: 
Required: false

### -exportStorContainerGroupMembershipExports
Description: 
Default Value: 
Required: false

### -exportGroupMemberships
Description: 
Default Value: False
Required: false

### -ChangeLicensesSelector
Description: 
Default Value: 0
Required: false

### -ChangeGroupsSelector
Description: "Change" and "Remove all" will both honour "groupToAdd"
Default Value: 0
Required: false

### -GroupToAdd
Description: 
Default Value: 
Required: false

### -GroupsToRemovePrefix
Description: 
Default Value: 
Required: false

### -RevokeGroupOwnership
Description: 
Default Value: True
Required: false

### -ManagerAsReplacementOwner
Description: 
Default Value: True
Required: false

### -ReplacementOwnerName
Description: Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

