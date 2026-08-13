# Notify Users About Stale Devices (Scheduled)

Notify primary users about their stale devices via email

## Detailed description
Identifies devices that haven't been active for a specified number of days and sends personalized email notifications to the primary users of those devices. The email contains device information and action steps for the user. Optionally filter users by including or excluding specific groups. Devices without a primary user (and devices whose primary user matches a configurable name pattern, e.g. Device Enrollment Manager accounts) can optionally be routed to the override email recipient while all other notifications are sent directly to the end users.

## Where to find
Org \ Devices \ Notify Users About Stale Devices_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each) and a custom footer link. When these settings are not configured, the default RealmJoin graphics are used. A branding image that cannot be downloaded or validated never prevents the report email - the default graphic is used instead.

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



## Notes
This runbook automatically sends personalized email notifications to users who have devices that haven't synced for a specified number of days.
The email is sent directly to the primary user's email address and includes detailed information about each inactive device.

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)
- Optional: Service Desk contact information can be configured (ServiceDesk_DisplayName, ServiceDesk_EMail, ServiceDesk_Phone, ServiceDesk_PortalUrl)

Common Use Cases:
- Automated user reminders about inactive devices to encourage regular device check-ins
- Proactive device lifecycle management by alerting users before devices are retired
- Security and compliance by ensuring users are aware of all devices registered to them
- Using MaxDays parameter for staged notifications (e.g., first reminder at 30 days, final notice at 60 days)
- User scope filtering to target specific departments or exclude service accounts
- Centrally handling devices without a primary user or owned by Device Enrollment Manager (e.g. DEM-*) accounts via the override recipient

Pilot and Testing Options:
- Use OverrideEmailRecipient parameter to send all notifications to a test mailbox instead of end users
- Perfect for validating email content and testing filters before rolling out to production
- Send notifications to ticket systems or shared mailboxes for centralized handling

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Group.Read.All
  - Mail.Send


## Parameters
### Days
Number of days without activity to be considered stale (minimum threshold).

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### MaxDays
Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | Int32 |

### Windows
Include Windows devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Include macOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Include iOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Include Android devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

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
Service Desk display name for user contact information (optional).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskEmail
Service Desk email address for user contact information (optional).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPhone
Service Desk phone number for user contact information (optional).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPortalUrl
Service Desk portal URL for user contact information, rendered as a clickable link (optional).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskTicketUrl
Direct link to a Service Desk ticket, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UseUserScope
Enable user scope filtering to include or exclude users based on group membership.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeUserGroup
Only send emails to users who are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeUserGroup
Do not send emails to users who are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverrideEmailRecipient
Optional: Email address(es) to send all notifications to instead of end users. Can be comma-separated for multiple recipients. Perfect for testing, piloting, or sending to ticket systems. If left empty, emails will be sent to the actual end users.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendNoPrimaryUserDevicesToOverride
If enabled, stale devices without a primary user (and devices whose primary user matches OverrideUserNamePattern) are sent to OverrideEmailRecipient, while all other notifications go directly to the end users. Requires OverrideEmailRecipient to be set. Devices without a primary user bypass user scope filtering.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### OverrideUserNamePattern
Optional wildcard pattern(s) matched against the primary user UPN (comma-separated, e.g. 'DEM-*,KIOSK-*', case-insensitive). Matching users' notifications are redirected to OverrideEmailRecipient. Only used when SendNoPrimaryUserDevicesToOverride is enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailTemplateLanguage
Select which email template to use: EN (English, default), DE (German), or Custom (from Runbook Customizations).

| Property | Value |
|----------|-------|
| Default Value | EN |
| Required | false |
| Type | String |

### CustomMailTemplateSubject
Custom email subject line (only used when MailTemplateLanguage is set to 'Custom').

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CustomMailTemplateBeforeDeviceDetails
Custom text to display before the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CustomMailTemplateAfterDeviceDetails
Custom text to display after the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

