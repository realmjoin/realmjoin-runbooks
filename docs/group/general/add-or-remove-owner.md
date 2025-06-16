# Add Or Remove Owner

## Add/remove owners to/from an Office 365 group.

## Description
Add/remove owners to/from an Office 365 group.

## Where to find
Group \ General \ Add Or Remove Owner

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - Directory.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -GroupID
Description: [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
Default Value: 
Required: true

### -UserId
Description: 
Default Value: 
Required: true

### -Remove
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

