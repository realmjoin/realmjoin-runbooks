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

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -DisplayName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -CreateTeam

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -Private

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -MailEnabled

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -SecurityEnabled

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -Owner

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -Owner2

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

