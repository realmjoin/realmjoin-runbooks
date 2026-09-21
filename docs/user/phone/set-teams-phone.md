# Set Teams Phone

Assign a phone number and voice policies to this user

## Detailed description
Assigns a phone number to this Teams user and optionally sets the voice routing policy, dial plan, calling policy and IP phone policy. Only the policies you fill in are changed. Enter Global (Org Wide Default) to remove an assignment and fall back to the tenant default.

## Where to find
User \ Phone \ Set Teams Phone

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

### PhoneNumber
Number to assign, in E.164 format such as +49123456789.

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


[Back to Table of Content](../../../README.md)

