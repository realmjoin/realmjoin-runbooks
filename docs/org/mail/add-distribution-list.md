# Add Distribution List

Create a classic distribution group

## Detailed description
Creates a classic Exchange Online distribution group with optional owner configuration. If no primary SMTP address is provided, the default verified domain is used.

## Where to find
Org \ Mail \ Add Distribution List

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### Alias
Mail alias (mail nickname) for the distribution group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### PrimarySMTPAddress
Optional primary SMTP address for the distribution group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupName
Optional display name for the distribution group; defaults to the alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Owner
Optional owner who can manage the group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Roomlist
If set to true, the distribution group is created as a room list.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AllowExternalSenders
If set to true, the group can receive email from external senders.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

