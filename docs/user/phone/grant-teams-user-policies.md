# Grant Teams User Policies

Assign Teams voice and meeting policies to this user

## Detailed description
Assigns Teams policies to this user: voice routing, dial plan, calling, IP phone, voicemail, meeting and live event policies. Only the policies you fill in are changed. Enter Global (Org Wide Default) to remove an assignment and fall back to the tenant default.

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
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### OnlineVoiceRoutingPolicy
Voice routing policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TenantDialPlan
Dial plan to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsCallingPolicy
Calling policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsIPPhonePolicy
IP phone policy to assign, typically for common area phones. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OnlineVoicemailPolicy
Voicemail policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsMeetingPolicy
Meeting policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### TeamsMeetingBroadcastPolicy
Live event (meeting broadcast) policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

