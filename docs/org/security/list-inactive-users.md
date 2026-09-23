# List Inactive Users

List users with no recent interactive sign-in

## Detailed description
Lists the users and guests whose last interactive sign-in is older than the chosen number of days. Accounts that are blocked from signing in and accounts that never signed in can be included. Nothing is changed.

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
Users with no interactive sign-in for at least this many days are listed.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### ShowBlockedUsers
Also lists users and guests whose sign-in is blocked.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ShowUsersThatNeverLoggedIn
Also lists users and guests that never signed in.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

