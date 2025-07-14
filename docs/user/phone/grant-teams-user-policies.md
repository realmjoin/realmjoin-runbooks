# Grant Teams User Policies

## Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.

## Description
Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

## Where to find
User \ Phone \ Grant Teams User Policies

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### -UserName
Description: User which should be granted the policies. Could be filled with the user picker in the UI.
Default Value: 
Required: true

### -OnlineVoiceRoutingPolicy
Description: Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TenantDialPlan
Description: Microsoft Teams Tenant Dial Plan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsCallingPolicy
Description: Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsIPPhonePolicy
Description: Microsoft Teams IP-Phone Policy Name (a.o. for Common Area Phone Users). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -OnlineVoicemailPolicy
Description: Microsoft Teams Online Voicemail Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsMeetingPolicy
Description: Microsoft Teams Meeting Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false

### -TeamsMeetingBroadcastPolicy
Description: Microsoft Teams Meeting Broadcast Policy Name (Live Event Policy). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

