# Notify Users About Stale Devices (Scheduled)

Email users about devices they have not used for a while

## Detailed description
Finds Intune devices that have not been active for a given number of days. Each primary user gets an email listing their stale devices and what to do about them. Users can be included or excluded by group. Emails can be redirected: all of them to an override address for tests, or those of accounts matching a name pattern to a dedicated recipient. Stale devices without a primary user can be collected into one combined email.

## Where to find
Org \ Devices \ Notify Users About Stale Devices_Scheduled

## Common use cases

- Automated user reminders about inactive devices to encourage regular device check-ins
- Proactive device lifecycle management by alerting users before devices are retired
- Security and compliance by ensuring users are aware of all devices registered to them
- Staged notifications via the `MaxDays` parameter, for example a first reminder at 30 days and a final notice at 60 days
- User scope filtering to target specific departments or to exclude service accounts
- Central handling of devices without a primary user or owned by Device Enrollment Manager accounts (for example `DEM-*`) via dedicated recipients

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

### Service Desk contact information

The optional `RJReport.ServiceDesk_DisplayName`, `RJReport.ServiceDesk_EMail`, `RJReport.ServiceDesk_Phone` and `RJReport.ServiceDesk_PortalUrl` tenant settings add a contact block to the end of every notification email. `ServiceDeskTicketUrl` can additionally link to a ticket.

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Group.Read.All
  - Mail.Send


## Parameters
### Days
Devices inactive for at least this many days count as stale.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### MaxDays
Only devices inactive for at most this many days are included. Leave empty for no upper limit.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | Int32 |

### Windows
Includes Windows devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Includes macOS devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Includes iOS and iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Includes Android devices.

| Property | Value |
|----------|-------|
| Default Value | True |
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
Link to the service desk ticket shown in the email. Leave empty for no link.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UseUserScope
Whether users are filtered by group membership. Set by the "Filter users by group?" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeUserGroup
Only users in this group are notified.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeUserGroup
Users in this group are not notified.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverrideEmailRecipient
Sends every email, including pattern-routed ones and the combined email, to these addresses instead of the normal recipients. For tests, pilots or a ticket system.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverrideUserNamePattern
Wildcard patterns for user names, separated by commas, for example DEM-*,KIOSK-*. Emails of matching users go to the "Recipient for pattern-matched users" instead.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UserNamePatternEmailRecipient
Addresses that receive the emails of users matching the pattern, separated by commas. Required when a pattern is set and no override is active.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendNoPrimaryUserDevicesToOverride
Collects stale devices that have no primary user into one combined email to the "Recipient for devices without primary user". Those devices ignore the user filter.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### NoPrimaryUserEmailRecipient
Addresses for the combined email, separated by commas. Required when the combined email is enabled and no override is set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailTemplateLanguage
English, German, or the custom template from the runbook customization; English is used where the custom template is empty.

| Property | Value |
|----------|-------|
| Default Value | EN |
| Required | false |
| Type | String |

### CustomMailTemplateSubject
Subject of the email when the custom template is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CustomMailTemplateBeforeDeviceDetails
Text above the device list when the custom template is used. Markdown is allowed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CustomMailTemplateAfterDeviceDetails
Text below the device list when the custom template is used. Markdown is allowed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

