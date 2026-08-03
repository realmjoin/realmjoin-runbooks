# Set Or Remove Mobile Phone MFA

Set or remove a user's mobile phone MFA method

## Detailed description
Adds, updates, or removes the user's mobile phone authentication method. This runbook manages phone numbers as regular MFA factors (call/text verification). Important: The Microsoft Graph phoneMethods API does not offer a way to add a phone number as "MFA only" without triggering an automatic SMS Sign-In registration attempt. If the user is enabled by the tenant's Authentication Methods Policy for SMS Sign-In, Graph will automatically try to register the number for SMS Sign-In after creating or updating the phone method. If the number is already used by another user for SMS Sign-In, Graph returns a 409 Conflict with error code "phoneNumberNotUnique". However, the phone method itself (for regular MFA) is typically created or updated successfully despite this error. The smsSignInState property is read-only and cannot be controlled via the create/update request. SMS Sign-In can only be explicitly managed via the separate enableSmsSignIn and disableSmsSignIn endpoints. This runbook verifies the actual state after such errors and reports success if the MFA method was assigned, with a warning about the SMS Sign-In conflict. If the assignment truly failed, it searches for the user holding the number.

## Where to find
User \ Security \ Set Or Remove Mobile Phone MFA

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their mobile phone MFA method was added, updated, or removed by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_set-or-remove-mobile-phone-mfa": {
    "parameters": {
        "UserId": {
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


## Notes
Permissions (managed identity, application):
- UserAuthenticationMethod.ReadWrite.All - manage phone authentication methods
- User.Read.All                           - resolve target user
- Organization.Read.All                  - read tenant display name for the email body
- Mail.Send                              - only required when NotifyUser is enabled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - UserAuthenticationMethod.ReadWrite.All
  - Mail.Send


## Parameters
### UserId
Object ID of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### phoneNumber
Mobile phone number in international E.164 format (e.g., +491701234567).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
"Set/Update Mobile Phone MFA Method" (final value: $false) or "Remove Mobile Phone MFA Method" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the mobile phone MFA method for the user. If set to false, it will add or update the mobile phone MFA method with the provided phone number.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### NotifyUser
When enabled, sends a notification email to the target user informing them that their mobile phone MFA method was added or removed by an administrator. Default is disabled.

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

