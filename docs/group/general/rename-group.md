# Rename Group

Rename this group or change its description

## Detailed description
Updates the display name, the mail nickname and the description of this group. Fill in only the fields you want to change; empty fields are left as they are. The group's email addresses do not change.

## Where to find
Group \ General \ Rename Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
New name of the group, for a team also the team name. Leave empty to keep the current name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailNickname
New alias (mail nickname) of the group. The existing email addresses stay. Leave empty to keep the current alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Description
New description shown for the group. Leave empty to keep the current one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

