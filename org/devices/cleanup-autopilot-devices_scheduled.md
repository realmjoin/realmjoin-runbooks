## Deletion is irreversible

- Removing an Autopilot device identity permanently deletes it from Windows Autopilot. There is no soft delete or recycle bin for Autopilot records.
- The physical device cannot re-enter Autopilot until its hardware hash is uploaded again.
- Deleting the Entra device object is likewise permanent; only do so for records that are genuinely dead, meaning the device will never enroll again.

## Recommended first run

1. Run with the delete mode *WhatIf (report only)*, which is the default, and review the output or the emailed CSV.
2. Confirm that the identified devices are genuinely orphaned or never enrolled.
3. Switch to a deletion mode only after the candidate list has been reviewed.

## Parameter interactions

- `DeleteMode` defaults to *WhatIf (report only)*; no deletions occur in that mode.
- *Delete Autopilot device* removes only the Autopilot identity. *Delete Autopilot and Entra device* additionally removes the matching Entra device object, which would otherwise be left behind as a stale record once the Autopilot identity is gone. The second mode requires the `Device.ReadWrite.All` permission.
- `CleanupOrphanedDevices` and `CleanupNeverEnrolledDevices` are independent; either or both can be enabled. `NeverEnrolledAgeDays` applies only to the never-enrolled check.
- `GroupTagFilter`, `ManufacturerFilter` and `ModelFilter` are optional; leave a filter empty to evaluate all values for that dimension. When more than one filter is set, they are combined with AND, so a device must match every populated filter to remain in scope. `GroupTagFilter` matches the group tag exactly (case-insensitive); `ManufacturerFilter` and `ModelFilter` match as case-insensitive substrings, so "Dell" matches "Dell Inc." and "Surface" matches "Surface Laptop 3".
- `ExcludeSerialNumbers` is applied after the AND filters as an exclusion: a device whose serial number is in the list (exact, case-insensitive) is removed from scope regardless of the other filters. Leave it empty to exclude nothing.

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
