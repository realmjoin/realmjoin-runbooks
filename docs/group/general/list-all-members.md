# List All Members

List all members of a group, including members that are part of nested groups

## Detailed description
This script retrieves the members of a specified EntraID group, including both direct members and those from nested groups.
The output is a CSV file with columns for User Principal Name (UPN), direct membership status, and group path.
The group path reflects the membership hierarchy—for example, “Primary, Secondary” if a user belongs to “Primary” via the nested group “Secondary.”

## Where to find
Group \ General \ List All Members

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - User.Read.All


## Parameters
### GroupId
The Object ID of the Microsoft Entra ID group whose membership will be retrieved.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

