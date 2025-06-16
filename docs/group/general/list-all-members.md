# List All Members

## Retrieves the members of a specified EntraID group, including members from nested groups.

## Description
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
### -GroupId
Description: The ObjectId of the EntraID group whose membership is to be retrieved.
Default Value: 
Required: true


[Back to Table of Content](../../../README.md)

