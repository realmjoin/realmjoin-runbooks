# Show Or Hide In Address Book

(Un)hide an O365- or static Distribution-group in Address Book.

## Detailed description
(Un)hide an O365- or static Distribution-group in Address Book. Can also show the current state.

## Where to find
Group \ Mail \ Show Or Hide In Address Book

## Notes
Note, as of 2021-06-28 MS Graph does not support updating existing groups - only on initial creation.
 PATCH : https://graph.microsoft.com/v1.0/groups/{id}
 body = { "resourceBehaviorOptions":["HideGroupInOutlook"] }

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -GroupName
Description: 
Default Value: 
Required: true

### -Action
Description: 
Default Value: 1
Required: false


[Back to Table of Content](../../../README.md)

