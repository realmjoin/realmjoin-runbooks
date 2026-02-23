# List Inactive Users

List users with no recent interactive sign-ins

## Detailed description
Lists users and guests that have not signed in interactively for a specified number of days. Optionally includes accounts that never signed in and accounts that are blocked.

## Where to find
Org \ Security \ List Inactive Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - AuditLog.Read.All
  - Organization.Read.All


## Parameters
### Days
Number of days without interactive sign-in.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### ShowBlockedUsers
If set to true, includes users and guests that cannot sign in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ShowUsersThatNeverLoggedIn
If set to true, includes users and guests that never signed in.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

