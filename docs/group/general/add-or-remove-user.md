# Add Or Remove User

Add a user to this group or remove one

## Detailed description
Adds a user as a member of this group or removes an existing member. Works for Microsoft Entra ID groups as well as Exchange Online distribution and mail-enabled security groups.

## Where to find
Group \ General \ Add Or Remove User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp *(optional: Mail-enabled groups)*

### RBAC roles
- Exchange Administrator *(optional: Mail-enabled groups)*


## Parameters
### GroupID
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserId
User who is added to or removed from the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Add makes the user a member. Remove takes the membership away.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

