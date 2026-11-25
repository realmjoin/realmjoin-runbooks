# Cleanup Duplicate Intune Devices (Scheduled)

Remove duplicate Intune devices, keeping the most recently synced

## Detailed description
Finds Intune devices that share a serial number and deletes the older records, keeping the one that synced most recently. Only the Intune record is deleted; the Entra ID device and the Autopilot registration stay. A deleted record cannot be restored. A preview mode lists the records without deleting anything. The report can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ Cleanup Duplicate Intune Devices_Scheduled

## How it works

The runbook lists the Intune managed devices of the tenant and looks for records that share the same serial number. Such duplicates typically appear when a device is re-enrolled or reinstalled and the old record stays behind. For each serial number it keeps the most recent record and removes the older ones.

### Scope and filters

- Platform toggles (`IncludeWindows`, `IncludeMacOS`, `IncludeIOS`, `IncludeAndroid`) limit the check to the selected operating systems.
- `DeviceNamePrefix` restricts the check to devices whose name starts with the given prefix.
- `IncludeSerialNumbers` and `ExcludeSerialNumbers` accept comma-separated serial numbers to restrict the check to, or to leave out, specific devices.
- Serial numbers are normalized before they are compared: upper and lower case and whitespace are ignored. Empty serial numbers and placeholder values such as `0`, `Default string`, `System Serial Number` or `To Be Filled By O.E.M.` (with or without spaces) are ignored, because they do not identify a device.

### Which record is kept

- Within a group of records with the same serial number, the record with the newest last sync time (`lastSyncDateTime`) is kept. A record that never synced is ranked by its enrollment time (`enrolledDateTime`) instead. The enrollment time also breaks ties.
- An older record is removed only when its own last sync is at least `MinimumDaysSinceLastSync` days ago, counted in whole days. For a record that never synced, the enrollment time is used. The kept record is not checked against this value.
- A device name that is empty is shown as `Unknown` in the output.

### When nothing is removed

The runbook removes a record only when the data clearly shows that it is the older one. All other duplicates are left alone and listed in the **Skipped duplicates** table together with the reason.

No record of a serial number is removed when:

- the two newest records have identical timestamps,
- the newest record has not synced yet, for example a fresh enrollment that has not checked in. The older records are removed by a later run, once the new record has synced,
- the records report different manufacturers, models or platforms. Different machines that share a serial number are not duplicates of one device. iOS and iPadOS count as one platform.

A single older record is skipped when:

- its last sync, or its enrollment if it never synced, is more recent than `MinimumDaysSinceLastSync` days,
- it was enrolled after the kept record, because last sync and enrollment time then disagree about which record is the newer one,
- it has neither a last sync nor an enrollment time.

### Safety measures

- **WhatIf mode is on by default.** In this mode (`WhatIfMode`) the runbook only lists what it would delete.
- `MaxDevicesToRemove` caps the number of deletions per run. The cap is checked before WhatIf: when more records qualify than the cap allows, nothing is deleted, and a WhatIf preview shows exactly the same outcome. The affected rows are marked `Would not be deleted (limit exceeded)` in WhatIf mode and `Not deleted (limit exceeded)` in a live run. Review the list and raise the cap deliberately if the number is correct.
- Only the Intune managed device record is deleted. The Entra ID device object and the Autopilot registration are not touched.
- A failed deletion does not stop the run. The record is marked `Failed`, the reason is shown in the `Details` column, and the runbook continues with the next one.

Recommended rollout:

1. Run the runbook with `WhatIfMode` enabled and review the output tables and the report.
2. Adjust filters, `MinimumDaysSinceLastSync` and `MaxDevicesToRemove` until the list matches your expectations.
3. Schedule the runbook with `WhatIfMode` disabled.

## Setup regarding download link

The optional download link uploads the report files to an Azure storage account and returns a time-limited link. It requires the storage account settings of the tenant (`RJReport.StorageAccount.*`) to be configured. The link expires after the number of days set in `RJReport.StorageAccount.LinkExpiryDays`. If the upload fails, the email report is still sent and the run ends as failed afterwards.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

## Setup regarding email sending

Sending an email report is optional and only happens when the `SendEmailReport` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting. An email is sent whenever at least one record qualified for removal. This includes WhatIf runs, runs in which deletions failed and runs in which the `MaxDevicesToRemove` limit stopped the deletion; the result column and a note in the email show what actually happened. No email is sent when no record qualified.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

The email contains a summary and the first 10 devices. The full list is attached as CSV and/or Excel file, depending on the selected report file format.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Interpreting the results

- The Output Data table **Duplicate devices** lists every record that qualified for removal together with the device that is kept. The result column shows `Deleted`, `Would be deleted`, `Failed` (with the reason in the `Details` column), or the limit-exceeded values described above. The removed and the kept record usually carry the same device name; their enrollment times, last sync times and Intune device IDs tell them apart.
- The Output Data table **Skipped duplicates** lists duplicates that were not removed and the reason, for example ambiguous timestamps or a last sync that is too recent.

## Scheduling

Run the runbook regularly, for example weekly, with `WhatIfMode` disabled once the results have been reviewed. Keep `MinimumDaysSinceLastSync` high enough that devices which are only temporarily offline are not affected.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*

### Permission notes
Azure: Storage Blob Data Contributor on the report storage account (only needed for the download link feature)


## Parameters
### WhatIfMode
List duplicate devices without deleting them. Disable to actually delete the older duplicate records.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeWindows
Include Windows devices in the duplicate detection.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMacOS
Include macOS devices in the duplicate detection.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeIOS
Include iOS and iPadOS devices in the duplicate detection.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeAndroid
Include Android devices in the duplicate detection.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DeviceNamePrefix
Check only devices whose name starts with this prefix. Leave empty to check all device names.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeSerialNumbers
Check only devices with one of these serial numbers (comma-separated). Leave empty to check all serial numbers.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeSerialNumbers
Skip devices with any of these serial numbers (comma-separated). Leave empty to exclude none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MinimumDaysSinceLastSync
An older duplicate record is deleted only when its last sync is at least this many days ago. For a record that never synced, its enrollment date counts instead. The kept record is not subject to this limit.

| Property | Value |
|----------|-------|
| Default Value | 7 |
| Required | false |
| Type | Int32 |

### MaxDevicesToRemove
Whole-run deletion cap. When more than this many devices would be deleted in a single run, nothing is removed and the affected records are listed as "Would not be deleted (limit exceeded)".

| Property | Value |
|----------|-------|
| Default Value | 50 |
| Required | false |
| Type | Int32 |

### EmailFrom
Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

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

### SendEmailReport
Send the report to the recipient email address when duplicates are or would be removed.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | cleanup-duplicate-intune-devices |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

