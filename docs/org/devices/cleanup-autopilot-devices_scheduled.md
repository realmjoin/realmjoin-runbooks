# Cleanup Autopilot Devices (Scheduled)

Clean up orphaned and stale Windows Autopilot device registrations

## Detailed description
This scheduled runbook performs regular maintenance of Windows Autopilot device registrations by identifying and removing orphaned devices whose serial numbers no longer match any Intune managed device, and optionally removing never-enrolled Autopilot devices that exceed a configurable age threshold. The runbook operates in WhatIf mode by default for safe reporting, and can optionally send an email summary with a CSV attachment listing the devices that would be or were deleted.

## Where to find
Org \ Devices \ Cleanup Autopilot Devices_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.


## Notes
Prerequisites:
- The Azure Automation managed identity must hold these Microsoft Graph application
  permissions: DeviceManagementManagedDevices.Read.All,
  DeviceManagementServiceConfig.ReadWrite.All, Organization.Read.All, Device.ReadWrite.All
  (Device.ReadWrite.All only when the "Delete Autopilot and Entra device" mode is used), and
  Mail.Send (Mail.Send only when email reporting is enabled).
- Grant the permissions before the first scheduled run.

Warning - deletion is irreversible:
- Removing an Autopilot device identity permanently deletes it from Windows Autopilot.
- The physical device cannot re-enter Autopilot until its hardware hash is re-uploaded.
- There is no soft-delete or recycle bin for Autopilot records.
- Deleting the Entra (Azure AD) device object is likewise permanent; only do so for records
  that are genuinely dead (the device will never enroll again).

Recommended first-run procedure:
- Run with Delete mode = "WhatIf (report only)" (the default) and review the output or emailed CSV.
- Confirm the identified devices are genuinely orphaned or never-enrolled.
- Switch to a deletion mode only after the candidate list has been reviewed.

Parameter interactions:
- DeleteMode defaults to "WhatIf (report only)"; no deletions occur in that mode.
- "Delete Autopilot device" removes only the Autopilot identity. "Delete Autopilot and Entra
  device" additionally removes the matching Entra (Azure AD) device object, which would
  otherwise be left behind as a stale/dead record once the Autopilot identity is gone.
- CleanupOrphanedDevices and CleanupNeverEnrolledDevices are independent; either or both
  can be enabled. NeverEnrolledAgeDays applies only to the never-enrolled check.
- GroupTagFilter, ManufacturerFilter and ModelFilter are all optional; leave a filter empty to
  evaluate all values for that dimension. When more than one filter is set they are combined with
  AND - a device must match every populated filter to remain in scope. GroupTagFilter matches the
  group tag exactly (case-insensitive); ManufacturerFilter and ModelFilter match as case-insensitive
  substrings, so "Dell" matches "Dell Inc." and "Surface" matches "Surface Laptop 3".

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.ReadWrite.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - Mail.Send
  - Organization.Read.All


## Parameters
### DeleteMode
Controls what the runbook does with the identified cleanup candidates. "WhatIf (report only)" performs no deletion and only reports the candidates (default, safe). "Delete Autopilot device" removes the Autopilot device identities. "Delete Autopilot and Entra device" removes the Autopilot identities and the matching Entra (Azure AD) device objects, which would otherwise remain as stale records.

| Property | Value |
|----------|-------|
| Default Value | WhatIf (report only) |
| Required | false |
| Type | String |

### GroupTagFilter
Comma-separated Autopilot group tags to limit the cleanup scope. Matched exactly (case-insensitive). Leave empty to process all Autopilot devices regardless of group tag.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ManufacturerFilter
Comma-separated device manufacturers to limit the cleanup scope. Matched as case-insensitive substrings, so "Dell" matches "Dell Inc.". Combined with the other filters using AND. Leave empty to process all manufacturers.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ModelFilter
Comma-separated device models to limit the cleanup scope. Matched as case-insensitive substrings, so "Surface" matches "Surface Laptop 3". Combined with the other filters using AND. Leave empty to process all models.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CleanupOrphanedDevices
When enabled, removes Autopilot devices that have contacted Intune in the past but whose serial number is no longer found among Intune managed devices (the managed device record was deleted).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### OrphanedLastContactedDays
Age threshold in days for orphaned devices. An Autopilot device is only treated as orphaned when its last contact with Intune was more than this number of days ago and its serial is no longer present in Intune. This prevents removing devices that contacted Intune recently.

| Property | Value |
|----------|-------|
| Default Value | 90 |
| Required | false |
| Type | Int32 |

### CleanupNeverEnrolledDevices
When enabled, removes never-enrolled Autopilot devices (devices that never contacted Intune).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### NeverEnrolledAgeDays
Age threshold in days for never-enrolled devices. Measured on the Device creation date.

| Property | Value |
|----------|-------|
| Default Value | 90 |
| Required | false |
| Type | Int32 |

### EmailTo
Optional email recipient address for the cleanup summary report. Leave empty to only write results to the runbook log.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address for the summary report. This is configured via Runbook Customizations.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

