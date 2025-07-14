# Set Out Of Office

## En-/Disable Out-of-office-notifications for a user/mailbox.

## Description
En-/Disable Out-of-office-notifications for a user/mailbox.

## Where to find
User \ Mail \ Set Out Of Office

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online API
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -Disable
Description: 
Default Value: False
Required: false

### -Start
Description: 
Default Value: (get-date)
Required: false

### -End
Description: 10 years into the future ("forever") if left empty
Default Value: ((get-date) + (new-timespan -Days 3650))
Required: false

### -MessageInternal
Description: 
Default Value: Sorry, this person is currently not able to receive your message.
Required: false

### -MessageExternal
Description: 
Default Value: Sorry, this person is currently not able to receive your message.
Required: false

### -CreateEvent
Description: 
Default Value: False
Required: false

### -EventSubject
Description: 
Default Value: Out of Office
Required: false


[Back to Table of Content](../../../README.md)

