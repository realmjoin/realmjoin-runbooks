# Delegate Send As

Grant or remove Send As permission on this user's mailbox

## Detailed description
Lets another person send email as this user, so messages appear to come from this mailbox, or removes that permission again. The permissions are shown before and after the change.

## Where to find
User \ Mail \ Delegate Send As

## Permissions
### Application permissions
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

### delegateTo
Person who gets or loses the Send As permission.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Whether the permission is removed instead of granted. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

