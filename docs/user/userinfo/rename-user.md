# Rename User

Rename a user or mailbox

## Detailed description
Renames a user by changing the user principal name in Microsoft Entra ID and optionally updates mailbox properties in Exchange Online. This does not update user metadata such as display name, given name, or surname.

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
### UserName
User principal name of the user or mailbox to rename.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NewUpn
New user principal name to set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ChangeMailnickname
If set to true, updates the mailbox alias and name based on the new UPN.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UpdatePrimaryAddress
If set to true, updates the primary SMTP address and rewrites email addresses accordingly.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

