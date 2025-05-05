# Set Teams Phone

## Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

## Description
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

## Where to find
User \ Phone \ Set Teams Phone

## Notes
Permissions:
MS Graph (API):
- Organization.Read.All

RBAC:
- Teams Administrator

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -PhoneNumber
Description: Number which should be assigned
Default Value: 
Required: true

### -OnlineVoiceRoutingPolicy
Description: 
Default Value: 
Required: false

### -TenantDialPlan
Description: 
Default Value: 
Required: false

### -TeamsCallingPolicy
Description: 
Default Value: 
Required: false

### -TeamsIPPhonePolicy
Description: 
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

