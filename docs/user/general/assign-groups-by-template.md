# Assign Groups By Template

Assign cloud-only groups to a user based on a template

## Detailed description
Adds a user to one or more Entra ID groups using either group object IDs or display names. The list of groups is typically provided via runbook customization templates.

## Where to find
User \ General \ Assign Groups By Template

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### UserId
ID of the target user in Microsoft Graph.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupsTemplate
Template selector used by portal customization to populate the group list.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsString
Comma-separated list of group object IDs or group display names.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UseDisplaynames
If set to true, treats values in GroupsString as group display names instead of IDs.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

