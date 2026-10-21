# Change Visibility

Make this group public or private

## Detailed description
Switches this Microsoft 365 group between public and private. Public groups can be found and joined by anyone in the organization, private groups only by their members. Membership, owners and email addresses stay as they are.

## Where to find
Group \ General \ Change Visibility

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### GroupID
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Public
Public groups can be found and joined by anyone in the organization, private groups only by their members.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

