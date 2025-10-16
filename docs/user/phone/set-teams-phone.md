# Set Teams Phone

Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

## Detailed description
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

## Where to find
User \ Phone \ Set Teams Phone

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### -UserName
Description: User which should be assigned. Could be filled with the user picker in the UI.
Default Value: 
Required: true

### -PhoneNumber
Description: Phone number which should be assigned to the user. The number must be in E.164 format (e.g. +49123456789).
Default Value: 
Required: true

### -OnlineVoiceRoutingPolicy
Description: Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TenantDialPlan
Description: Microsoft Teams DialPlan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsCallingPolicy
Description: Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsIPPhonePolicy
Description: Microsoft Teams IP Phone Policy Name (a.o. for Common Area Phone Users). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

