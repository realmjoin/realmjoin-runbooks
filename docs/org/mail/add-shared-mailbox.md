# Add Shared Mailbox

Create a shared mailbox with optional delegates

## Detailed description
Creates a shared mailbox in Exchange Online with the chosen language and time zone. Delegates can get full access and send on behalf of the mailbox, and sent mails can be kept in the shared Sent Items folder. The user account behind the mailbox can be disabled so nobody signs in with it. If a setting cannot be applied, the mailbox is kept and the run fails, naming what is missing.

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

## Offer only the time zones you use

The time zone list holds the Windows time zones named after places, sorted by their offset from UTC as in Windows and Outlook. The offset in each entry is the standard time. Exchange Online applies daylight saving time on its own, so Sydney is listed as UTC+10:00 and runs at UTC+11:00 from October to April.

With a runbook customization the operator sees only the time zones of your locations:

```json
{
    "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "TimeZone",
                    "SelectSimple": {
                        "(UTC-05:00) Eastern Time (US & Canada)": "Eastern Standard Time",
                        "(UTC+00:00) Dublin, Edinburgh, Lisbon, London": "GMT Standard Time",
                        "(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna": "W. Europe Standard Time",
                        "(UTC+10:00) Canberra, Melbourne, Sydney": "AUS Eastern Standard Time"
                    },
                    "Default": "W. Europe Standard Time"
                }
            ]
        }
    }
}
```

The text on the left is shown in the portal, the value on the right is the Windows time zone ID that Exchange Online stores. Take both from the portal options of the time zone parameter below. `Default` names the ID that is preselected.

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
Time zone used for the calendar and timestamps of the mailbox. The list shows the standard time offset; daylight saving time is applied automatically where the region uses it.

| Property | Value |
|----------|-------|
| Default Value | W. Europe Standard Time |
| Required | false |
| Type | String |

### DelegateTo
People who get full access to the mailbox and can send on its behalf. You can pick several at once; leave empty for none. Nothing is created if one of them is not found in Exchange Online.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String Array |

### AutoMapping
The mailbox opens automatically in the delegates' Outlook.

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
Blocks sign-in for the user account behind the mailbox. Delegates keep their access. If the account does not appear within a few minutes, the run fails and sign-in has to be blocked in Entra ID.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

