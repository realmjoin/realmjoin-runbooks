# Add Or Remove Email Address

Add an email address to this user's mailbox or remove one

## Detailed description
Adds an alias address to the mailbox of this user or removes one. A new or existing address can also be made the primary address that outgoing mail is sent from.

## Where to find
User \ Mail \ Add Or Remove Email Address

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

### EmailAddress
Address to add or remove, for example jane.doe@contoso.com.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Whether the address is removed instead of added. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### asPrimary
Makes this address the primary one that outgoing mail is sent from.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

