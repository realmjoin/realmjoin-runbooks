# Set Teams Permanent Call Forwarding

Set immediate call forwarding for a Teams user

## Detailed description
Configures immediate call forwarding for a Teams Enterprise Voice user to a Teams user, a phone number, voicemail, or the user's delegates. The runbook can also disable immediate forwarding.

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
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ForwardTargetPhoneNumber
Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789)

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ForwardTargetTeamsUser
User principal name of the Teams user to forward calls to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ForwardToVoicemail
If set to true, forwards calls to voicemail.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ForwardToDelegates
If set to true, forwards calls to the delegates defined by the user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TurnOffForward
If set to true, disables immediate call forwarding.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

