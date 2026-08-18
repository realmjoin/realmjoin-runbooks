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

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.
