# Delete Stale Devices (Scheduled)

Scheduled deletion of stale devices based on last activity date and platform

## Detailed description
Identifies Intune managed devices that have not been active for a specified number of days.
By default the runbook runs in report-only mode (simulation) and lists the devices that would be deleted.
When deletion is enabled, the matching devices are deleted from Intune and the results are included in the report.
An email report with CSV and/or Excel (xlsx) attachments can be sent optionally and the report files can also be uploaded to an Azure Storage Account, returning time-limited download links.

## Where to find
Org \ Devices \ Delete Stale Devices_Scheduled

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
  - Mail.Send *(optional: Email report)*


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

