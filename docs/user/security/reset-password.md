# Reset Password

Set a new password for this user

## Detailed description
Sets a new password for this user in Entra ID and shows it in the output. A disabled account can be enabled first, and the user can be made to choose their own password at the next sign-in.

## Where to find
User \ Security \ Reset Password

## Permissions
### RBAC roles
- User Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EnableUserIfNeeded
Enables a disabled account before the password is set.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ForceChangePasswordNextSignIn
Makes the user choose their own password at the next sign-in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

