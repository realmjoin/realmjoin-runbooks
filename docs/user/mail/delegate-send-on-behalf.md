# Delegate Send On Behalf

Delegate SendOnBehalf permissions for the user's mailbox

## Detailed description
Grants or removes SendOnBehalf permissions for a delegate on the user's mailbox. Outputs the resulting SendOnBehalf trustees after applying the change.
This allows the delegate to send emails on behalf of the mailbox owner.

## Where to find
User \ Mail \ Delegate Send On Behalf

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online API
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the mailbox.

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

