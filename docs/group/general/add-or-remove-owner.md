# Add Or Remove Owner

Add an owner to this group or remove one

## Detailed description
Makes a user an owner of this group or removes an existing owner. For Microsoft 365 groups a new owner is also made a member.

## Where to find
Group \ General \ Add Or Remove Owner

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### GroupID
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserId
User who gets or loses the ownership.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Add makes the user an owner. Remove takes the user off the owner list.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

