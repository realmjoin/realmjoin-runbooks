# Set Teams Permanent Call Forwarding

Forward this user's calls immediately or turn forwarding off

## Detailed description
Sets up immediate call forwarding for this Teams Enterprise Voice user to another Teams user, a phone number, voicemail or the user's own delegates. It can also switch immediate forwarding off again. Unanswered-call handling is turned off at the same time.

## Where to find
User \ Phone \ Set Teams Permanent Call Forwarding

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

### ForwardTargetPhoneNumber
Number that receives the calls, in E.164 format such as +49123456789.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ForwardTargetTeamsUser
Colleague whose Teams account rings instead of this user's.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ForwardToVoicemail
Sends the calls to voicemail. Set by the "Forward calls to" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ForwardToDelegates
Sends the calls to the delegates the user has defined in Teams. Set by the "Forward calls to" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TurnOffForward
Switches immediate forwarding off. Set by the "Forward calls to" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

