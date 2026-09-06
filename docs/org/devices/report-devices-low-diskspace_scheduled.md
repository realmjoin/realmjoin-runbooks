# Report Devices Low Diskspace (Scheduled)

Scheduled report of managed devices running low on free disk space.

## Detailed description
Identifies and lists Intune managed devices whose free disk space is below a configurable threshold, either a fixed amount of free space in gigabytes or a percentage of the total disk size.
The result can be narrowed down by platform and by manufacturer and model filters, and each reported device is rated as Critical or Warning depending on how far below the threshold it is.
Automatically sends a report via email with CSV and/or Excel (xlsx) attachments.
The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

## Where to find
Org \ Devices \ Report Devices Low Diskspace_Scheduled

## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the report describes the state of the last successful inventory rather than the current state of the device. Use the **Last Sync** column of the report to judge how up to date an individual row is.

Devices that report a total disk size of zero bytes have no usable storage inventory. This is common for Android Enterprise work profiles and also happens on devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being reported as "0 GB free", and their number is shown in the console output and in the email summary.

Windows and macOS are included by default, iOS/iPadOS and Android are not. The default threshold of 20 GB is dimensioned for desktop disks and would report a large number of perfectly healthy mobile devices. When you enable the mobile platforms, the percentage based threshold (`ThresholdType` = *Free space below a percentage of the disk size*) usually gives more meaningful results.

## Threshold and severity

`ThresholdType` selects whether a device is reported based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every reported device is rated: devices below half of the configured threshold are marked as **Critical**, all other reported devices as **Warning**. In the Excel workbook these ratings are highlighted in red and yellow.

## Report delivery

Report files are only generated when a delivery method is used, that is when a recipient (`EmailTo`) is provided and/or `CreateDownloadLink` is enabled. Without either, the result is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

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


## Notes
This runbook complements the reporting foundation and delivers a recurring overview of devices that are about to run out of disk space,
so that affected users can be contacted before the lack of free space starts to block updates, app installations or profile synchronization.

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)

Data source and freshness:
The free and total disk space values are taken from the Intune hardware inventory of each device, which is refreshed with the regular device check-in.
They therefore describe the state of the last successful inventory and not necessarily the current state, so the Last Sync column of the report should be used to judge how up to date a row is.
Devices that report a total disk size of zero bytes have no usable storage inventory (this is common for Android Enterprise work profiles) and are excluded from the evaluation, but their number is reported.

Platform defaults:
Windows and macOS are included by default, iOS/iPadOS and Android are not, because the default threshold in gigabytes is dimensioned for desktop disks
and would report a large number of perfectly healthy mobile devices. When mobile platforms are enabled, the percentage based threshold usually gives more meaningful results.

Common Use Cases:
- Recurring disk space monitoring across the managed device fleet
- Finding devices that are likely to fail feature updates or app deployments because of insufficient free space
- Preparing targeted user communication or cleanup campaigns
- Checking a specific hardware generation via the manufacturer and model filters

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Organization.Read.All *(optional: Email report)*
  - Mail.Send *(optional: Email report)*

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when CreateDownloadLink is used)


## Parameters
### ThresholdType
Determines how low disk space is detected, either by a fixed amount of free space in gigabytes or by the percentage of free space relative to the disk size.

| Property | Value |
|----------|-------|
| Default Value | Free space in GB |
| Required | false |
| Type | String |

### FreeSpaceThresholdGB
Devices with less free disk space than this value in gigabytes are reported. Only used when the threshold type is set to free space in gigabytes.

| Property | Value |
|----------|-------|
| Default Value | 20 |
| Required | false |
| Type | Int32 |

### FreeSpacePercentThreshold
Devices with a lower percentage of free disk space than this value are reported. Only used when the threshold type is set to free space in percent.

| Property | Value |
|----------|-------|
| Default Value | 10 |
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
Include iOS and iPadOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Android
Include Android devices in the results.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ManufacturerFilter
Optional comma-separated list of manufacturer names. A device is included when its manufacturer contains one of the entries. Leave empty to include all manufacturers.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ModelFilter
Optional comma-separated list of model names. A device is included when its model contains one of the entries. Leave empty to include all models.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization

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

### BrandingAccentColor
Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Optional text color override (6-digit hex) for the report email template.
Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

| Property | Value |
|----------|-------|
| Default Value | XLSX only |
| Required | false |
| Type | String |

### CreateDownloadLink
If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | report-devices-low-diskspace |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for the upload. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |

### EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

