# Auto Approve Driver Updates (Scheduled)

Auto-approve new driver updates in Intune driver update policies

## Detailed description
This scheduled runbook automatically approves pending driver updates in one or more Intune driver update policies. It can filter driver updates by display name pattern, driver class, or manufacturer. Optional email notifications can be sent after approval operations complete.
The notification email includes CSV and/or Excel (xlsx) report files listing every driver approval action (policy, driver, version, manufacturer, driver class, release date and outcome).
The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

## Where to find
Org \ Devices \ Auto Approve Driver Updates_Scheduled

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
Prerequisites:
- Microsoft Graph BETA API access (driver update endpoints are in beta)
- RJReport.EmailSender setting configured (if email notifications are used)

Common Use Cases:
- Test filters first: Use WhatIf parameter to preview which drivers would be approved
- Auto-approve all drivers: Run without any filter parameters
- Approve specific manufacturers: Use DriverManufacturer to target vendors like "Intel" or "AMD"
- Target specific policies: Use PolicyNames or PolicyIds to scope to test policies first
- Monitor approvals: Configure EmailTo to receive detailed reports after each run

Parameter Interactions:
- If no policy filter is specified, ALL driver update policies are processed
- If no driver filter is specified, ALL pending drivers in selected policies are approved
- PolicyNames and PolicyIds can be combined - both filters apply independently
- Email notifications require RJReport.EmailSender setting and Connect-RjRbGraph
- WhatIf mode simulates approvals without making changes - useful for testing filters

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All


## Parameters
### PolicyNames
(Optional) Comma-separated list of driver update policy names to scope the approval (e.g., "Policy1, Policy2, Policy3"). If not specified, all policies are processed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PolicyIds
(Optional) Comma-separated list of driver update policy IDs to scope the approval (e.g., "id1, id2, id3"). If not specified, all policies are processed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverDisplayNamePattern
(Optional) Filter driver updates by display name pattern (supports wildcards). Only matching drivers will be approved.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverClass
(Optional) Filter by driver class IDs (comma-separated). Example: "Bluetooth,Networking,Firmware" for specific driver classes.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverManufacturer
(Optional) Filter by driver manufacturer name. Only drivers from the specified manufacturer will be approved.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MaximumDriverAge
(Optional) Maximum age in days for drivers to be approved. Only drivers released within the last X days will be approved. Example: 30 to only approve drivers released in the last 30 days.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### OnlyNeedsReview
When enabled (default), only drivers with status "needsReview" are approved. Drivers with status "suspended" or "declined" are skipped. Disable to also re-approve suspended or declined drivers.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### WhatIf
(Optional) When enabled, simulates driver approvals without making actual changes. Shows which drivers would be approved and sends a report to EmailTo if configured.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | SwitchParameter |

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
| Default Value | auto-approve-driver-updates |
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

### EmailFrom
Sender email address for notifications. This parameter is backed by a setting and should not be modified directly.

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

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
(Optional) Recipient email address for approval notifications. If not specified, no email is sent.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

