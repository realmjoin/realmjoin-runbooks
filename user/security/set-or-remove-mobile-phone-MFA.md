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
