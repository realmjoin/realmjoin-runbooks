# Add Or Remove Safelinks Exclusion

## Add or remove a SafeLinks URL exclusion to/from a given policy.

## Description
Add or remove a SafeLinks URL exclusion to/from a given policy.
It can also be used to initially create a new policy if required.

## Where to find
Org \ General \ Add Or Remove Safelinks Exclusion

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -Action
Description: 
Default Value: 2
Required: false

### -LinkPattern
Description: URL to allow, can contain '*' as wildcard for host and paths
Default Value: https://*.microsoft.com/*
Required: false

### -DefaultPolicyName
Description: If only one policy exists, no need to specify. Will use "DefaultPolicyName" as default otherwise.
Default Value: Default SafeLinks Policy
Required: true

### -PolicyName
Description: Optional, will overwrite default values
Default Value: 
Required: false

### -CreateNewPolicyIfNeeded
Description: 
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)

