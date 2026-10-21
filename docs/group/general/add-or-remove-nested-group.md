# Add Or Remove Nested Group

Add a nested group to this group or remove it

## Detailed description
Adds another group as a member of this group, or removes that nesting again. Works for Microsoft Entra ID groups as well as Exchange Online distribution and mail-enabled security groups.

## Where to find
Group \ General \ Add Or Remove Nested Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
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

### NestedGroupID
Group that becomes a member of this group, or stops being one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Add makes the chosen group a member of this group. Remove takes an existing nesting away.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

