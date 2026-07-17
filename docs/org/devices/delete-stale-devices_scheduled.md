# Delete Stale Devices (Scheduled)

Scheduled deletion of stale devices based on last activity date and platform

## Detailed description
Identifies Intune managed devices that have not been active for a specified number of days.
By default the runbook runs in report-only mode (simulation) and lists the devices that would be deleted.
When deletion is enabled, the matching devices are deleted from Intune and the results are included in the report.
An email report with CSV and/or Excel (xlsx) attachments can be sent optionally and the report files can also be uploaded to an Azure Storage Account, returning time-limited download links.

## Where to find
Org \ Devices \ Delete Stale Devices_Scheduled

## Notes
This runbook deletes managed devices from Intune based on inactivity. Use with care!

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting) when email reporting is used

Common Use Cases:
- Regular cleanup of stale device records in Intune
- Simulation runs (report-only mode) before enabling actual deletion
- Scheduled lifecycle management with an audit trail via email report

The runbook supports optional user scope filtering to include or exclude devices based on primary user group membership.
This acts as an additional safety net when deletion is enabled.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - Directory.Read.All
  - Device.Read.All
  - Mail.Send


## Parameters
### Days
Number of days without activity to be considered stale.

| Property | Value |
|----------|-------|
| Default Value | 30 |
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

### DeleteDevices
If set to true, the matching stale devices are deleted from Intune.
If false (default), the runbook only reports which devices would be deleted (simulation).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
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
| Default Value | delete-stale-devices |
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

### UseUserScope
Enable user scope filtering to include or exclude devices based on primary user group membership.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeUserGroup
Only include devices whose primary users are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeUserGroup
Exclude devices whose primary users are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

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

