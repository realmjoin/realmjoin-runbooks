# Add Shared Mailbox

Create a shared mailbox.

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
### -MailboxName
Description: The alias (mailbox name) for the shared mailbox.
Default Value: 
Required: true

### -DisplayName
Description: The display name for the shared mailbox.
Default Value: 
Required: false

### -DomainName
Description: The domain name to be used for the primary SMTP address of the shared mailbox. If not specified, the default domain will be used.
Default Value: 
Required: false

### -Language
Description: The language/locale for the shared mailbox. This setting affects folder names like "Inbox". Default is "en-US".
Default Value: en-US
Required: false

### -DelegateTo
Description: The user to delegate access to the shared mailbox.
Default Value: 
Required: false

### -AutoMapping
Description: If set to true, the shared mailbox will be automatically mapped in Outlook for the delegate user.
Default Value: False
Required: false

### -MessageCopyForSentAsEnabled
Description: If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent as the shared mailbox.
Default Value: True
Required: false

### -MessageCopyForSendOnBehalfEnabled
Description: If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent on behalf of the shared mailbox.
Default Value: True
Required: false

### -DisableUser
Description: If set to true, the associated EntraID user account will be disabled.
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)

