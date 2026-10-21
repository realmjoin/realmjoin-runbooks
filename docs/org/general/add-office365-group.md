# Add Office365 Group

Create a Microsoft 365 group, optionally with a team

## Detailed description
Creates a Microsoft 365 group with its SharePoint site and, on request, turns it into a Microsoft Teams team. Visibility, mail and security settings and up to two owners can be set. A team without an owner gets the caller as owner.

## Where to find
Org \ General \ Add Office365 Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Create
  - Team.Create
  - Group.Read.All
  - User.Read.All *(optional: Owner assignment)*


## Parameters
### MailNickname
Alias of the group, used for its email address and SharePoint URL.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Name shown for the group. Leave empty to use the mail nickname.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateTeam
Creates only the group with its SharePoint site, or also a Microsoft Teams team on top of it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Private
Public groups can be found and joined by anyone in the organization, private groups only by their members.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MailEnabled
Gives the group a mailbox and email address.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SecurityEnabled
Lets the group be used for permissions and access assignments.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Owner
Owner of the group. Leave empty for none; a team then gets the caller as owner.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner2
Additional owner. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

