# Rename Group

Rename a group.

## Detailed description
This runbook updates a group's DisplayName, MailNickname, and Description.
It does not change the group's email addresses.
Provide only the fields you want to update; empty values are ignored.

## Where to find
Group \ General \ Rename Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### GroupId
Object ID of the group to update.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
New display name for the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailNickname
New mail nickname (alias) for the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Description
New description for the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

