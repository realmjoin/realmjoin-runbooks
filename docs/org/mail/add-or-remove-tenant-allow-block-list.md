# Add Or Remove Tenant Allow Block List

Add or remove entries from the Tenant Allow/Block List.

## Detailed description
Add or remove entries from the Tenant Allow/Block List in Microsoft Defender for Office 365.
Allows blocking or allowing senders, URLs, or file hashes. A new entry is set to expire in 30 days by default.

## Where to find
Org \ Mail \ Add Or Remove Tenant Allow Block List

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -Entry
The entry to add or remove (e.g., domain, email address, URL, or file hash).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -ListType
The type of entry: Sender, Url, or FileHash.

| Property | Value |
|----------|-------|
| Default Value | Sender |
| Required | false |
| Type | String |

### -Block
Decides whether to block or allow the entry.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -Remove
Decides whether to remove or add the entry.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -DaysToExpire
Number of days until the entry expires. Default is 30 days.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

