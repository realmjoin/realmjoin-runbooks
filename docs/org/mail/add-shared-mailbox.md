# Add Shared Mailbox

Create a shared mailbox with optional delegate

## Detailed description
Creates a shared mailbox in Exchange Online with the chosen language and time zone. A delegate can get full access, and sent mails can be kept in the shared Sent Items folder. The user account behind the mailbox can be disabled so nobody signs in with it.

## Where to find
Org \ Mail \ Add Shared Mailbox

## Offer the accepted domains as a list

The domain of the new mailbox is free text by default. With a runbook customization the operator picks it from the accepted domains of the tenant instead:

```json
{
        "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "DomainName",
                    "Select": {
                        "Options": [
                                {
                                    "Value": "contoso.onmicrosoft.com"
                                },
                                {
                                    "Value": "contoso.com"
                                }
                            ]
                    },
                    "DefaultValue": "contoso.com"
                }
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp
- **Type**: Microsoft Graph
  - User.ReadWrite.All *(optional: Disable user account)*

### RBAC roles
- Exchange Administrator


## Parameters
### MailboxName
Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Name shown in the address book. Leave empty to use the alias.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DomainName
Domain of the email address. Leave empty to use the default domain of the tenant.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Language
Language of the mailbox, which sets the names of the default folders such as Inbox.

| Property | Value |
|----------|-------|
| Default Value | en-US |
| Required | false |
| Type | String |

### TimeZone
Time zone used for the calendar and timestamps of the mailbox.

| Property | Value |
|----------|-------|
| Default Value | W. Europe Standard Time |
| Required | false |
| Type | String |

### DelegateTo
User who gets full access to the mailbox. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AutoMapping
The mailbox opens automatically in the delegate's Outlook.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MessageCopyForSentAsEnabled
Mails sent as the shared mailbox are also stored in its Sent Items folder.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MessageCopyForSendOnBehalfEnabled
Mails sent on behalf of the shared mailbox are also stored in its Sent Items folder.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DisableUser
Blocks sign-in for the user account behind the mailbox. Delegates keep their access.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

