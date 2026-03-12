# Add Security Group

Create a Microsoft Entra ID security group

## Detailed description
This runbook creates a Microsoft Entra ID security group with membership type Assigned.
It validates the group name and optionally sets an owner during creation.

## Where to find
Org \ General \ Add Security Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Create


## Parameters
### GroupName
Display name of the security group to create.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupDescription
Optional description for the security group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner
Optional owner to assign to the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

