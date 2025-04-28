# Add Or Remove Teams Mailcontact

## Create/Remove a contact, to allow pretty email addresses for Teams channels.

## Description
Create/Remove a contact, to allow pretty email addresses for Teams channels.

## Where to find
Org \ Mail \ Add Or Remove Teams Mailcontact

## Notes
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp

## Parameters
### -RealAddress
Description: Enter the address created by MS Teams for a channel
Default Value: 
Required: true

### -DesiredAddress
Description: Will forward/relay to the real address.
Default Value: 
Required: true

### -DisplayName
Description: 
Default Value: 
Required: false

### -Remove
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

