# Add Office365 Group

Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

## Detailed description
Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

## Where to find
Org \ General \ Add Office365 Group

## Notes
Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
MS Graph (API):
- Group.Create
- Team.Create

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Create
  - Team.Create


## Parameters
### -MailNickname
Description: 
Default Value: 
Required: true

### -DisplayName
Description: 
Default Value: 
Required: false

### -CreateTeam
Description: 
Default Value: False
Required: false

### -Private
Description: [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is private" } )]
Default Value: False
Required: false

### -MailEnabled
Description: [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is mail-enabled" } )]
Default Value: False
Required: false

### -SecurityEnabled
Description: [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is security-enabled" } )]
Default Value: True
Required: false

### -Owner
Description: 
Default Value: 
Required: false

### -Owner2
Description: 
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

