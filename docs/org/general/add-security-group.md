# Add Security Group

Create a security group in Entra ID

## Detailed description
Creates a security group in Entra ID with assigned membership, so it can be used for permissions and access assignments. Names that contain a blocked word or are already in use are rejected. An owner can be set right away.

## Where to find
Org \ General \ Add Security Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Create
  - Group.Read.All


## Parameters
### GroupName
Name shown in Entra ID. Must be unique and must not contain a blocked word.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupDescription
Short text that explains what the group is for. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner
User who becomes owner of the group. Leave empty for no owner.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

