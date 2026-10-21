# Add Distribution List

Create a classic Exchange Online distribution group

## Detailed description
Creates a classic distribution group in Exchange Online, optionally as a room list, with an owner, or open to external senders. Without an email address the alias at the default domain of the tenant is used.

## Where to find
Org \ Mail \ Add Distribution List

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### Alias
Short name that becomes the part of the email address in front of the @ sign, for example MKTG for the marketing team.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### PrimarySMTPAddress
Address the group sends and receives with. Leave empty to use the alias at the default domain.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupName
Name shown in the address book. Leave empty to use the alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner
User who manages the members of the group. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Roomlist
Creates the group as a room list, so its rooms can be picked together in the Outlook room finder.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AllowExternalSenders
Lets people outside the organization send email to the group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

