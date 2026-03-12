# Add Shared Mailbox

Create a shared mailbox

## Detailed description
This script creates a shared mailbox in Exchange Online and configures various settings such as delegation, auto-mapping, and message copy options.
Also if specified, it disables the associated EntraID user account.

## Where to find
Org \ Mail \ Add Shared Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### MailboxName
The alias (mailbox name) for the shared mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Display name for the shared mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DomainName
Optional domain used for the primary SMTP address; if not provided, the default domain is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Language
The language/locale for the shared mailbox. This setting affects folder names like "Inbox". Default is "en-US".

| Property | Value |
|----------|-------|
| Default Value | en-US |
| Required | false |
| Type | String |

### DelegateTo
Optional user who receives delegated access to the mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AutoMapping
If set to true, the mailbox is automatically mapped in Outlook for the delegate.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MessageCopyForSentAsEnabled
If set to true, copies of messages sent as the mailbox are stored in the mailbox sent items.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MessageCopyForSendOnBehalfEnabled
If set to true, copies of messages sent on behalf of the mailbox are stored in the mailbox sent items.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DisableUser
If set to true, the associated Entra ID user account is disabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

