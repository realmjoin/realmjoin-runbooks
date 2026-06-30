# Reset MFA

Remove all App- and Mobilephone auth methods for a user

## Detailed description
Removes authenticator app and phone-based authentication methods for a user. This forces the user to re-enroll MFA methods after the reset. Optionally a notification email can be sent to the user informing them that their MFA methods have been reset through this runbook.

## Where to find
User \ Security \ Reset MFA

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their MFA methods were reset by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_reset-mfa": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "LanguageOverride": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending a notification email is optional and only happens when `NotifyUser` is enabled. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.ReadWrite.All
  - Mail.Send


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NotifyUser
When enabled, sends a notification email to the target user informing them that their MFA methods were reset by an administrator. Default is disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender email address for the optional notification mail. Sourced from the RealmJoin tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskDisplayName
Service Desk display name for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_DisplayName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskEmail
Service Desk email address for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_EMail.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPhone
Service Desk phone number for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_Phone.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPortalUrl
Service Desk portal URL for user contact information, rendered as a clickable link (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_PortalUrl.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskTicketUrl
Direct link to the Service Desk ticket related to this request, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LanguageOverride
Overrides the language used for the notification email. Accepted values are 'DE' (German) or 'EN' (English). If left empty, the language is determined automatically based on the target user's usage location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

