# Notify Users About Stale Devices (Scheduled)

Notify primary users about their stale devices via email

## Detailed description
Identifies devices that haven't been active for a specified number of days and sends personalized email notifications to the primary users of those devices. The email contains device information and action steps for the user. Optionally filter users by including or excluding specific groups.

## Where to find
Org \ Devices \ Notify Users About Stale Devices_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

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



## Notes
This runbook automatically sends personalized email notifications to users who have devices that haven't synced for a specified number of days.
The email is sent directly to the primary user's email address and includes detailed information about each inactive device.

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)
- Optional: Service Desk contact information can be configured (ServiceDesk_DisplayName, ServiceDesk_EMail, ServiceDesk_Phone)

Common Use Cases:
- Automated user reminders about inactive devices to encourage regular device check-ins
- Proactive device lifecycle management by alerting users before devices are retired
- Security and compliance by ensuring users are aware of all devices registered to them
- Using MaxDays parameter for staged notifications (e.g., first reminder at 30 days, final notice at 60 days)
- User scope filtering to target specific departments or exclude service accounts

Pilot and Testing Options:
- Use OverrideEmailRecipient parameter to send all notifications to a test mailbox instead of end users
- Perfect for validating email content and testing filters before rolling out to production
- Send notifications to ticket systems or shared mailboxes for centralized handling

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All
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

