# Rename User

Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

## Detailed description
Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

## Where to find
User \ Userinfo \ Rename User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - User.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -NewUpn

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -ChangeMailnickname

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -UpdatePrimaryAddress

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

