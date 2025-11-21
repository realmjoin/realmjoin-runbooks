# Set Teams Permanent Call Forwarding

Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user.

## Detailed description
Set up instant call forwarding for a Microsoft Teams Enterprise Voice user. Forwarding to another Microsoft Teams Enterprise Voice user or to an external phone number.

## Where to find
User \ Phone \ Set Teams Permanent Call Forwarding

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### -UserName
User which should be set up. Could be filled with the user picker in the UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -ForwardTargetPhoneNumber
Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -ForwardTargetTeamsUser
Teams user to which calls should be forwarded. Could be filled with the user picker in the UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -ForwardToVoicemail
Forward calls to voicemail.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -ForwardToDelegates
Forward calls to delegates which are defined by the user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -TurnOffForward
Turn off immediate call forwarding.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

