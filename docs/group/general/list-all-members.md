# List All Members

List all members of this group, nested groups included

## Detailed description
Lists every member of this Entra ID group, both direct members and those who belong through nested groups. The result is a CSV-formatted list with the user principal name, whether the membership is direct, and the group path. A path like "Primary, Secondary" means the user is in Primary through the nested group Secondary.

## Where to find
Group \ General \ List All Members

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - User.Read.All


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

