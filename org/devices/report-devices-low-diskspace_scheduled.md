## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the report describes the state of the last successful inventory rather than the current state of the device. Use the **Last Sync** column of the report to judge how up to date an individual row is.

Devices that report a total disk size of zero bytes have no usable storage inventory. This is common for Android Enterprise work profiles and also happens on devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being reported as "0 GB free", and their number is shown in the console output and in the email summary.

Windows and macOS are included by default, iOS/iPadOS and Android are not. The default threshold of 20 GB is dimensioned for desktop disks and would report a large number of perfectly healthy mobile devices. When you enable the mobile platforms, the percentage based threshold (`ThresholdType` = *Free space below a percentage of the disk size*) usually gives more meaningful results.

## Threshold and severity

`ThresholdType` selects whether a device is reported based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every reported device is rated: devices below half of the configured threshold are marked as **Critical**, all other reported devices as **Warning**. In the Excel workbook these ratings are highlighted in red and yellow.

## Report delivery

Report files are only generated when a delivery method is used, that is when a recipient (`EmailTo`) is provided and/or `CreateDownloadLink` is enabled. Without either, the result is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

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
