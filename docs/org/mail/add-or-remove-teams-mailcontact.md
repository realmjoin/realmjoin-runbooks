# Add Or Remove Teams Mailcontact

Give a Teams channel a friendly email address or remove it

## Detailed description
Creates a mail contact that forwards a friendly email address to the long address Teams generates for a channel. People can then email the channel with an address they can remember. The same runbook removes the friendly address again.

## Where to find
Org \ Mail \ Add Or Remove Teams Mailcontact

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### RealAddress
Email address that Teams generated for the channel.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DesiredAddress
Friendly address that should forward to the channel.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Name shown for the contact in the address book. Leave empty to use the part of the friendly address before the @ sign.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Remove
Set up the friendly address creates the mail contact; Remove the friendly address deletes it again.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

