# Add Or Remove Email Address

Add or remove an email address for a mailbox

## Detailed description
Adds or removes an alias email address on a mailbox and can optionally set it as the primary address.

## Where to find
User \ Mail \ Add Or Remove Email Address

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

### EmailAddress
Email address to add or remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
If set to true, removes the address instead of adding it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### asPrimary
If set to true, sets the specified address as the primary SMTP address.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

