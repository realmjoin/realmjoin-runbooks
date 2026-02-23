# Delegate Send As

Delegate SendAs permissions for other user on his/her mailbox or remove existing delegation

## Detailed description
Grants or removes SendAs permissions for a delegate on a mailbox in Exchange Online. The current permissions are shown before and after applying the change.
This allows the delegate to send emails as if they were the mailbox owner.

## Where to find
User \ Mail \ Delegate Send As

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online API
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### delegateTo
User principal name of the delegate.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
If set to true, removes the delegation instead of granting it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

