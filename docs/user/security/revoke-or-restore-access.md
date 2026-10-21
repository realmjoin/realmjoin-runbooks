# Revoke Or Restore Access

Block this user's sign-in and sessions, or restore access

## Detailed description
Blocks this user from signing in and ends the current sessions, so stolen tokens stop working immediately, for example during an incident. Re-enable user lifts the block again; ended sessions are not restored.

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
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Revoke
Revoke access blocks sign-in and ends the sessions. Re-enable user lets the user sign in again.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

