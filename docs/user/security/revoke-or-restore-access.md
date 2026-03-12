# Revoke Or Restore Access

Revoke or restore user access

## Detailed description
Blocks or re-enables a user account and optionally revokes active sign-in sessions. This can be used during incident response to immediately invalidate user tokens.

## Where to find
User \ Security \ Revoke Or Restore Access

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All

### RBAC roles
- User Administrator


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Revoke
"(Re-)Enable User" (final value: $false) or "Revoke Access" (final value: $true) can be selected as action to perform. If set to true, the runbook will block the user from signing in and revoke active sessions. If set to false, it will re-enable the user account.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

