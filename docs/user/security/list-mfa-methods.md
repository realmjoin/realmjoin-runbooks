# List MFA Methods

List all MFA / authentication methods of a user

## Detailed description
Retrieves and displays every Microsoft Entra ID authentication method registered for a target user, including phone numbers for phone-based methods. Phone numbers can optionally be masked, showing only the last four digits. Optionally a notification email can be sent to the user informing them that their MFA methods have been retrieved through this runbook.

## Where to find
User \ Security \ List MFA Methods

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their MFA methods were retrieved by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_list-mfa-methods": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "MaskPhoneNumbers": {
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

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each) and a custom footer link. When these settings are not configured, the default RealmJoin graphics are used. A branding image that cannot be downloaded or validated never prevents the report email - the default graphic is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.


## Notes
Permissions (managed identity, application):
- UserAuthenticationMethod.Read.All - list authentication methods
- User.Read.All                      - resolve target user
- Organization.Read.All              - read tenant display name for the email body
- Mail.Send                          - only required when NotifyUser is enabled

Privacy / audit:
- This runbook reads sensitive identity data (registered MFA methods, including phone numbers).
  Phone numbers are masked by default. Set MaskPhoneNumbers to false only when full numbers are
  required for legitimate support purposes; the action is logged with CallerName.
- When NotifyUser is enabled, the target user is notified by email that an administrator has
  retrieved their MFA methods. This requires the tenant setting RJReport.EmailSender to be
  configured.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### UserName
User Principal Name of the target user. Auto-filled by the RealmJoin portal in the user context.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NotifyUser
When enabled, sends a notification email to the target user informing them that their MFA methods were retrieved by an administrator. Default is disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaskPhoneNumbers
When enabled, all phone numbers are masked except for the last four digits (for example +491234567890 becomes ********7890). Default is disabled.

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

### BrandingHeaderImageUrl
Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
When empty, the default link (https://www.realmjoin.com) is used.

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

