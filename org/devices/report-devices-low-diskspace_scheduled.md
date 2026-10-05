## Common use cases

- Recurring disk space monitoring across the managed device fleet
- Finding devices that are likely to fail feature updates or app deployments because of insufficient free space
- Preparing targeted user communication or cleanup campaigns, for example with **Notify Users About Low Diskspace**
- Checking a specific hardware generation via the manufacturer and model filters

## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the report describes the state of the last successful inventory rather than the current state of the device. Use the **Last Sync** column of the report to judge how up to date an individual row is.

Devices that report a total disk size of zero bytes have no usable storage inventory. This is common for Android Enterprise work profiles and also happens on devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being reported as "0 GB free", and their number is shown in the console output and in the email summary.

This report deliberately lists devices regardless of how old their inventory is, so that a device which stopped checking in still shows up. Its user-facing counterpart **Notify Users About Low Diskspace** does the opposite: it skips devices whose last Intune sync is older than its `MaxInventoryAgeDays` setting, so that nobody is asked to free up space based on outdated numbers. Both runbooks apply the same threshold and the same Critical/Warning rating, so a device is rated identically in both - but this report can list more devices than the notification runbook writes to. The difference is exactly the devices with a stale inventory, and the notification runbook reports their number in its own output.

Windows and macOS are included by default, iOS/iPadOS and Android are not. The default threshold of 20 GB is dimensioned for desktop disks and would report a large number of perfectly healthy mobile devices. When you enable the mobile platforms, the percentage based threshold (`ThresholdType` = *Free space below a percentage of the disk size*) usually gives more meaningful results.

## Threshold and severity

`ThresholdType` selects whether a device is reported based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every reported device is rated: devices below half of the configured threshold are marked as **Critical**, all other reported devices as **Warning**. In the Output Data tab each rating has its own table (*Critical devices*, *Warning devices*, worst devices first); in the Excel workbook the ratings are highlighted in red and yellow.

## Report delivery

Every run writes a **Summary** table and the device tables per rating to the Output Data tab of the RealmJoin portal, where each table can also be exported to Excel. Report files (CSV and/or Excel workbook) are only generated when the **Report delivery** option includes an email or a download link. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission). A failed upload is reported as a warning and does not stop the email delivery.

Schedules that were created before the **Report delivery** option existed keep sending their email: a stored recipient alone still enables the email for them. When such a schedule is opened for editing, the option shows *Output Data only*; select the delivery again before saving, otherwise the schedule stops sending the report.

When no device is below the threshold, no report file is created; a selected email delivery still sends a short confirmation without attachments.

## Setup regarding email sending

Sending an email report is optional and only happens when the **Report delivery** option includes an email; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).
