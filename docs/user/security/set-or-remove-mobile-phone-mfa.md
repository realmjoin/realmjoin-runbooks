# Set Or Remove Mobile Phone MFA

Set or remove the mobile phone MFA method of this user

## Detailed description
Adds or updates the mobile phone of this user as an MFA method for calls and text messages, or removes it. Optionally the user gets an email about the change. When the tenant allows SMS sign-in, Microsoft also tries to register the number for it. A number already used by someone else then produces a warning; the MFA method is usually still set, and the runbook checks and reports the real state. Details on that conflict are in the runbook documentation (docs.realmjoin.com).

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

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## SMS sign-in conflicts

The Microsoft Graph phone methods API offers no way to add a phone number as an MFA-only method without Microsoft also attempting to register it for SMS sign-in. When the user is enabled for SMS sign-in by the tenant's authentication methods policy, Graph tries that registration right after the phone method is created or updated. If another user already uses the number for SMS sign-in, Graph answers with a `409 Conflict` and the error code `phoneNumberNotUnique`, although the phone method for regular MFA is usually created or updated anyway.

The `smsSignInState` property is read-only and cannot be set in the create or update request; SMS sign-in can only be switched explicitly through the separate `enableSmsSignIn` and `disableSmsSignIn` endpoints. The runbook therefore checks the real state after such an error and reports success with a warning when the MFA method was assigned. If the assignment really failed, it looks up the user who holds the number and names them in the output.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - UserAuthenticationMethod.ReadWrite.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email notification)*


## Parameters
### UserId
Object ID of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### phoneNumber
Number in E.164 format such as +491701234567.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
Add or update stores the number as the MFA method for calls and text messages. Remove deletes it.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### NotifyUser
Whether the user is emailed about the change. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskDisplayName
Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskEmail
Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPhone
Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPortalUrl
Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskTicketUrl
Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LanguageOverride
Forces the email language, DE or EN. Empty picks the language from the user's usage location. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

