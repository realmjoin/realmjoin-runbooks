# Delegate Full Access

Delegate FullAccess permissions to another user on a mailbox or remove existing delegation

## Detailed description
Grants or removes FullAccess permissions for a delegate on a mailbox. Optionally enables Outlook automapping when granting access.
Also shows the current and new permissions for the mailbox.
Automapping allows the delegated mailbox to automatically appear in the delegate's Outlook client.

## Where to find
User \ Mail \ Delegate Full Access

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
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

### AutoMapping
If set to true, enables Outlook automapping when granting FullAccess.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

