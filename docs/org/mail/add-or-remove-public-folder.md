# Add Or Remove Public Folder

Create or remove an Exchange Online public folder

## Detailed description
Creates a public folder in Exchange Online, optionally in a chosen public folder mailbox, or removes an existing one. At least one public folder mailbox must already exist; the runbook does not create any.

## Where to find
Org \ Mail \ Add Or Remove Public Folder

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### PublicFolderName
Name of the public folder to create or remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### MailboxName
Public folder mailbox the new folder is created in. Leave empty to let Exchange choose.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AddPublicFolder
Whether the folder is created or removed. Set by the action selected in the portal.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

