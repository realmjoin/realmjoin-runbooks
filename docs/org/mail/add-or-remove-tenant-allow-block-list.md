# Add Or Remove Tenant Allow Block List

Add or remove entries from the Tenant Allow/Block List

## Detailed description
Adds or removes entries from the Tenant Allow/Block List in Microsoft Defender for Office 365. The runbook supports senders, URLs, and file hashes and sets new entries to expire after 30 days by default.

## Where to find
Org \ Mail \ Add Or Remove Tenant Allow Block List

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### Entry
The entry to add or remove (for example: domain, email address, URL, or file hash).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ListType
Type of entry to manage.

| Property | Value |
|----------|-------|
| Default Value | Sender |
| Required | false |
| Type | String |

### Block
"Block List (block entry)" (final value: $true) or "Allow List (permit entry)" (final value: $false) can be selected as list type.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Remove
"Add entry to the list" (final value: $false) or "Remove entry from the list" (final value: $true) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DaysToExpire
Number of days until a newly added entry expires.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

