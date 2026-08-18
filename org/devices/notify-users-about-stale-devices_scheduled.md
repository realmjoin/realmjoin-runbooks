## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.

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

## Routing Devices Without a Primary User to the Override Recipient

By default, stale devices without a primary user are skipped, and a filled `OverrideEmailRecipient` redirects **all** notifications. Enabling `SendNoPrimaryUserDevicesToOverride` changes this: devices without a primary user (and devices whose primary user matches `OverrideUserNamePattern`) are sent to the `OverrideEmailRecipient`, while all other notifications go directly to the end users.

| `SendNoPrimaryUserDevicesToOverride` | `OverrideEmailRecipient` | Behavior |
| --- | --- | --- |
| Off | empty | Devices without a primary user are skipped; users are mailed directly. |
| Off | set | All notifications are redirected to the override recipient. |
| On | set | Devices without a primary user are collected into **one** combined email to the override recipient. Users matching the pattern are redirected to the override recipient. All other users receive their notification directly. |
| On | empty | Invalid configuration - the runbook stops with an error. |

### User Name Pattern

`OverrideUserNamePattern` accepts one or more wildcard patterns (comma-separated) matched against the primary user's UPN, e.g. `DEM-*` for Device Enrollment Manager accounts or `DEM-*,KIOSK-*` for multiple patterns. Matching is case-insensitive and uses PowerShell wildcard syntax (`*`, `?`). The pattern is only evaluated when `SendNoPrimaryUserDevicesToOverride` is enabled.

**Important Notes:**

- Enabling `SendNoPrimaryUserDevicesToOverride` requires `OverrideEmailRecipient` to be set
- Devices without a primary user bypass the user scope filtering (they have no user to match against groups)
- Pattern-matched users are still subject to user scope filtering first; users excluded by scope produce no notification at all
- The combined email for devices without a primary user uses an administrative wording (no end-user action steps), independent of custom templates

