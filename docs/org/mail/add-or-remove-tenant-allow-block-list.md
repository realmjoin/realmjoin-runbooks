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
Description: The entry to add or remove (e.g., domain, email address, URL, or file hash).
Default Value: 
Required: true

### -ListType
Description: The type of entry: Sender, Url, or FileHash.
Default Value: Sender
Required: false

### -Block
Description: Decides whether to block or allow the entry.
Default Value: True
Required: false

### -Remove
Description: Decides whether to remove or add the entry.
Default Value: False
Required: false

### -DaysToExpire
Description: Number of days until the entry expires. Default is 30 days.
Default Value: 30
Required: false


[Back to Table of Content](../../../README.md)

