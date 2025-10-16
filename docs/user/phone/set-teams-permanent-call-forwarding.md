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
Description: User which should be set up. Could be filled with the user picker in the UI.
Default Value: 
Required: true

### -ForwardTargetPhoneNumber
Description: Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789).
Default Value: 
Required: false

### -ForwardTargetTeamsUser
Description: Teams user to which calls should be forwarded. Could be filled with the user picker in the UI.
Default Value: 
Required: false

### -ForwardToVoicemail
Description: Forward calls to voicemail.
Default Value: False
Required: false

### -ForwardToDelegates
Description: Forward calls to delegates which are defined by the user.
Default Value: False
Required: false

### -TurnOffForward
Description: Turn off immediate call forwarding.
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

