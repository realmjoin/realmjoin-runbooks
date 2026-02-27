# Add Or Remove Public Folder

Add or remove a public folder

## Detailed description
Creates or removes an Exchange Online public folder. The runbook assumes that at least one public folder mailbox already exists and does not provision public folder mailboxes.

## Where to find
Org \ Mail \ Add Or Remove Public Folder

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### PublicFolderName
Name of the public folder to create or remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### MailboxName
Optional target public folder mailbox to create the folder in.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AddPublicFolder
If set to true, the public folder is created; if set to false, it is removed.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

