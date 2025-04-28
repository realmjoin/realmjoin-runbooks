# Enable Or Disable External Mail

## Enable/disable external parties to send eMails to O365 groups.

## Description
Enable/disable external parties to send eMails to O365 groups.

## Where to find
Group \ Mail \ Enable Or Disable External Mail

## Notes
Permissions: 
 Office 365 Exchange Online
 - Exchange.ManageAsApp
Azure AD Roles
 - Exchange administrator
Notes: Setting this via graph is currently broken as of 2021-06-28: 
 attribute: allowExternalSenders
 https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property

## Parameters
### -GroupId
Description: 
Default Value: 
Required: true

### -Action
Description: 
Default Value: 0
Required: false


[Back to Table of Content](../../../README.md)

