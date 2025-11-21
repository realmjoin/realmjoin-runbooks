# List Inactive Users

List users, that have no recent interactive signins.

## Detailed description
This runbook lists users and guests from Azure AD, that have not signed in interactively for a specified number of days.
It can also include users/guests that have never logged in.

## Where to find
Org \ Security \ List Inactive Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - AuditLog.Read.All
  - Organization.Read.All


## Parameters
### -Days
Number of days without interactive signin.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### -showBlockedUsers
Include users/guests that can not sign in (accountEnabled = false).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -showUsersThatNeverLoggedIn
Beware: This has to enumerate all users / Can take a long time.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

