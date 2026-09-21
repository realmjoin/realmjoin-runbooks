# Add Or Remove Tenant Allow Block List

Add or remove a Tenant Allow/Block List entry

## Detailed description
Adds a sender, URL or file hash to the Tenant Allow/Block List of Defender for Office 365, or removes it again. New entries expire after the chosen number of days, so temporary exceptions clean themselves up.

## Where to find
Org \ Mail \ Add Or Remove Tenant Allow Block List

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### Entry
What to allow or block: a domain, an email address, a URL, or a file hash, matching the entry type.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ListType
Sender takes a domain or email address, URL a web address, File hash a SHA-256 hash.

| Property | Value |
|----------|-------|
| Default Value | Sender |
| Required | false |
| Type | String |

### Block
Block list rejects matching mail, URLs or files; Allow list lets them through even when Defender would filter them.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Remove
Add the entry creates it with the chosen expiry; Remove the entry deletes the existing entry with the same value.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DaysToExpire
Days until a new entry expires and is removed automatically.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

