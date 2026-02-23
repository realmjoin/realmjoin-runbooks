# Grant Teams User Policies

Grant Microsoft Teams policies to a Microsoft Teams enabled user

## Detailed description
Assigns selected Teams policies for a Teams-enabled user. Policies are only changed when a value is provided, and assignments can be cleared by using the value "Global (Org Wide Default)".
It allows to assign the following policies: Online Voice Routing Policy, Tenant Dial Plan, Teams Calling Policy, Teams IP Phone Policy, Online Voicemail Policy, Teams Meeting Policy and Teams Meeting Broadcast Policy (Live Event Policy).

## Where to find
User \ Phone \ Grant Teams User Policies

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### OnlineVoiceRoutingPolicy
Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TenantDialPlan
Microsoft Teams Tenant Dial Plan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsCallingPolicy
Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsIPPhonePolicy
Microsoft Teams IP Phone Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. This is typically used for Common Area Phone users.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OnlineVoicemailPolicy
Microsoft Teams Online Voicemail Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsMeetingPolicy
Microsoft Teams Meeting Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsMeetingBroadcastPolicy
Microsoft Teams Meeting Broadcast Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

