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
