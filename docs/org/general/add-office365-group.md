# Add Office365 Group

Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

## Detailed description
This runbook creates a Microsoft 365 group and provisions the related SharePoint site.
It can optionally promote the group to a Microsoft Teams team after creation.

## Where to find
Org \ General \ Add Office365 Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Create
  - Team.Create


## Parameters
### MailNickname
Mail nickname used for group creation.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Optional display name. If empty, MailNickname is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateTeam
Choose to "Only create a SharePoint Site" (final value: $false) or "Create a Team (and SharePoint Site)" (final value: $true). A team needs an owner, so if CreateTeam is set to true and no owner is specified, the runbook will set the caller as the owner.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Private
Choose the group visibility: "Public" (final value: $false) or "Private" (final value: $true).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MailEnabled
If set to true, the group is mail-enabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SecurityEnabled
If set to true, the group is security-enabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Owner
Optional owner of the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner2
Optional second owner of the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

