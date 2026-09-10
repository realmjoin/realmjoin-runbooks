## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the runbook sees the state of the last successful inventory rather than the current state of the device. To avoid notifying users based on outdated numbers, devices whose last Intune sync is older than `MaxInventoryAgeDays` (default 14 days) are skipped and counted separately. Devices without a last sync date are treated as outdated as well. Set the parameter to `0` to disable this check.

The companion **Report Devices Low Diskspace** runbook deliberately does not apply this filter, so it lists devices with a stale inventory as well and can show more devices than are notified here. Both runbooks apply the same threshold and the same Critical/Warning rating, so a device is rated identically in both; the difference in the device count is exactly the devices skipped for an outdated inventory, which this runbook reports as a separate number in its output.

Devices that report a total disk size of zero bytes have no usable storage inventory, for example devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being treated as "0 GB free", and their number is shown in the console output.

Only Windows and macOS devices are evaluated. The storage inventory of mobile devices is less reliable, the default threshold in gigabytes is dimensioned for desktop disks, and the cleanup guidance in the email is specific to desktop operating systems.

This runbook is the user-facing counterpart of **Report Devices Low Diskspace**. Both use the same threshold settings and the same Critical/Warning rating. Use the report for the administrative overview, including devices without a primary user, and this runbook to ask the affected users to free up space themselves.

## Threshold and severity

`ThresholdType` selects whether a device is considered based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every device below the threshold is rated: devices below half of the configured threshold are marked as **Critical**, all other devices below the threshold as **Warning**. The rating is shown per device in the email, and with the built-in English and German templates the subject line and introduction switch to an urgent wording as soon as one of the user's devices is Critical. The `Custom` template has a single subject and a single introduction, both taken verbatim from the runbook customization, so a Critical and a Warning notification read identically there - phrase the custom text so it works for both.

`NotifyOnSeverity` controls which devices trigger a notification. By default every device below the threshold does (*Warning and Critical*). With *Critical only*, users are contacted only when a device is below half of the threshold. This allows a two-stage approach: report all devices below the threshold to administrators via the report runbook, and notify only the users whose devices are critical.

## Notification behaviour

The runbook sends **one email per primary user** that lists all affected devices of that user with operating system, model, free and total disk space, rating and the date of the last inventory. The email contains practical cleanup steps for the platforms of the listed devices: the Windows section is included for Windows devices, the macOS section for macOS devices, and both when the user has affected devices of both kinds.

Recipients are resolved via Microsoft Graph: the primary user of a device is looked up by the Entra object id that Intune reports in `userId`, so guest accounts and users whose current UPN differs from the address recorded at enrollment resolve correctly; devices without a `userId` fall back to a lookup by user principal name. The email is then sent to the user's `mail` attribute, with the user principal name as fallback when no mail attribute is set. Disabled accounts and users that cannot be resolved are skipped and listed in the console output. Devices without a primary user cannot be notified; they are listed in the console output for central follow-up (the report runbook covers them as well).

`SimulationMode` lists the affected users, their devices and the intended recipients in the console output without sending any email. Use it to validate thresholds and scope filters before the first productive run.

`OverrideEmailRecipient` redirects **ALL** notifications to the given address (comma-separated for multiple recipients) instead of the end users. A warning is logged on every run while the override is active, and each redirected email states the affected user in the subject and body. Use this for testing the email content or for routing everything to a shared mailbox.

## Scoping options

- **User scope:** With `UseUserScope` enabled, `IncludeUserGroup` limits the notifications to users who are members of that group, and `ExcludeUserGroup` suppresses notifications for members of that group. Both use the transitive membership, so nested groups are resolved, and both are read once at the start of the run.
- **Device scope:** `IncludeDeviceGroup` limits the evaluation to devices that are (transitive) members of the given Entra device group. Devices are matched via their Entra device ID.

When a user scope and a device scope are configured, a device has to match both. A failing group lookup stops the runbook with an error instead of silently notifying every user.

## Setup regarding email sending

The notification emails are sent to the affected users; the sender address is taken from the `RJReport.EmailSender` tenant setting and is required.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The notification email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

### Service Desk contact information

The optional `RJReport.ServiceDesk_DisplayName`, `RJReport.ServiceDesk_EMail`, `RJReport.ServiceDesk_Phone` and `RJReport.ServiceDesk_PortalUrl` tenant settings add a contact block to the end of every email. `ServiceDeskTicketUrl` can additionally link to a ticket.

## Mail Template Language Selection

This runbook supports three email template options:

1. **EN (English - Default)**: Uses the built-in English template
2. **DE (German)**: Uses the built-in German template
3. **Custom**: Uses a custom template from Runbook Customizations

### Using Custom Mail Templates

To use a custom mail template (e.g., in Dutch, Spanish, or any other language), you need to configure the template text in the Runbook Customizations. If any custom template parameter is missing, the runbook will automatically fall back to the English template.

The custom template consists of a subject, a text before the device list and a text after the device list. The built-in cleanup steps, the "Why is this important" section and the "Questions" section are **not** rendered with the custom template, so the text after the device list should contain your own cleanup guidance.

#### Example: Custom Template

```json
{
    "Runbooks": {
        "rjgit-org_devices_notify-users-about-low-diskspace_scheduled": {
            "Parameters": {
                "CustomMailTemplateSubject": {
                    "Default": "This is a custom subject - Action Required: Low Disk Space"
                },
                "CustomMailTemplateBeforeDeviceDetails": {
                    "Default": "**This is above the Device Details.** \n\nDear user, the following devices are running out of disk space:"
                },
                "CustomMailTemplateAfterDeviceDetails": {
                    "Default": "**This is below the Device Details.** \n\n## What you can do now\n\n1. Empty the Recycle Bin\n2. ..."
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
- The device list labels are rendered in English for the custom template
