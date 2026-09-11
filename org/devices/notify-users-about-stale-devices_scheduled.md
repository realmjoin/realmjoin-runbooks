## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Mail Template Language Selection

This runbook supports three email template options:

1. **EN (English - Default)**: Uses the built-in English template
2. **DE (German)**: Uses the built-in German template
3. **Custom**: Uses a custom template from Runbook Customizations

### Using Custom Mail Templates

To use a custom mail template (e.g., in Dutch, Spanish, or any other language), you need to configure the template text in the Runbook Customizations. If any custom template parameter is missing, the runbook will automatically fall back to the English template.

#### Example: Custom Template

```json
{
    "Runbooks": {
        "rjgit-org_devices_notify-users-about-stale-devices_scheduled": {
            "Parameters": {
                "CustomMailTemplateSubject": {
                    "Default": "This is a custom subject - Action Required: Inactive Devices"
                },
                "CustomMailTemplateBeforeDeviceDetails": {
                    "Default": "**This is above the Device Details.** \n\nDear user ..."
                },
                "CustomMailTemplateAfterDeviceDetails": {
                    "Default": "**This is below the Device Details.** \n\n## What you should do..."
                }
            }
        }
    }
}
```

**Important Notes:**
- Use `\n` for line breaks in the JSON configuration
- Markdown formatting (##, ###, **, -) is supported in the template text
- All three custom template parameters (Subject, BeforeDeviceDetails, AfterDeviceDetails) should be configured
- If any parameter is missing, the runbook automatically falls back to the English (EN) template
- When using the custom template, select "Custom - Use Template from Runbook Customizations" in the Mail Template dropdown

## Email Routing

The runbook knows three independent routing targets, checked in this order of precedence:

1. **Global override (testing):** A filled `OverrideEmailRecipient` redirects **ALL** emails - user notifications, pattern-routed notifications and the combined email for devices without a primary user - to that address. No end user receives an email. Use this for testing, piloting, or routing everything to a shared mailbox or ticket system. A warning is logged on every run while the override is active.
2. **Pattern-matched users:** When `OverrideUserNamePattern` is set, notifications of users whose UPN matches the pattern are sent to `UserNamePatternEmailRecipient` instead of the user. All other users receive their notification directly. Typical use: Device Enrollment Manager or kiosk accounts (`DEM-*`, `KIOSK-*`) whose mailboxes nobody reads.
3. **Devices without a primary user:** When `SendNoPrimaryUserDevicesToOverride` is enabled, stale devices without a primary user are collected into **one** combined email to `NoPrimaryUserEmailRecipient`. Otherwise these devices are skipped. This setting never changes how user notifications are routed.

Incomplete configurations stop the runbook with an error instead of silently mailing end users:

- `SendNoPrimaryUserDevicesToOverride` enabled without `NoPrimaryUserEmailRecipient` (and without a global override) - error.
- `OverrideUserNamePattern` set without `UserNamePatternEmailRecipient` (and without a global override) - error.
- A recipient set without its feature (`NoPrimaryUserEmailRecipient` without the toggle, `UserNamePatternEmailRecipient` without a pattern) - warning, the recipient is ignored.

While the global override is active, the dedicated recipients do not need to be set - everything goes to the override recipient anyway.

### User Name Pattern

`OverrideUserNamePattern` accepts one or more wildcard patterns (comma-separated) matched against the primary user's UPN, e.g. `DEM-*` for Device Enrollment Manager accounts or `DEM-*,KIOSK-*` for multiple patterns. Matching is case-insensitive and uses PowerShell wildcard syntax (`*`, `?`). When the pattern routing is active, the runbook logs a warning stating which pattern is redirected to which recipient.

**Important Notes:**

- All recipient parameters accept multiple comma-separated addresses
- Devices without a primary user bypass the user scope filtering (they have no user to match against groups)
- Pattern-matched users are still subject to user scope filtering first; users excluded by scope produce no notification at all
- The combined email for devices without a primary user uses an administrative wording (no end-user action steps), independent of custom templates
- Redirected notifications state the affected user in the email subject and body
