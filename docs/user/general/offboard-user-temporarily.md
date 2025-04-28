# Offboard User Temporarily

## Temporarily offboard a user.

## Description
Temporarily offboard a user in cases like parental leaves or sabaticals.

## Where to find
User \ General \ Offboard User Temporarily

## Notes
Permissions
AzureAD Roles
- User administrator
Azure IaaS: "Contributor" access on subscription or resource group used for the export

## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -RevokeAccess
Description: 
Default Value: True
Required: false

### -DisableUser
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
Default Value: False
Required: false

### -ReplacementOwnerName
Description: Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

