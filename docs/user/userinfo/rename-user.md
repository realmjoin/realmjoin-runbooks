# Rename User

Change this user's sign-in name (UPN) and mailbox alias

## Detailed description
Gives this user a new user principal name in Entra ID and, optionally, updates the mailbox alias and the primary email address in Exchange Online to match. Display name, given name and surname are not touched.

## Where to find
User \ Userinfo \ Rename User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NewUpn
New sign-in name, for example jane.doe@contoso.com.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ChangeMailnickname
Sets the mailbox alias and name from the new user principal name.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UpdatePrimaryAddress
Makes the new user principal name the primary email address; the previous addresses stay as aliases.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

