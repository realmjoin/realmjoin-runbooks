# Report Windows Devices Without Autopilot (Scheduled)

Report Windows devices in Entra ID without an Autopilot record

## Detailed description
Lists Windows device objects in Entra ID that no Windows Autopilot registration refers to. Such orphaned objects are usually left over from devices that were reset, re-imaged or replaced without cleanup, so the list shows what can be reviewed and deleted. Nothing is changed. The report can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ Report Windows Devices Without Autopilot_Scheduled

## Reporting orphaned Windows devices

This runbook lists every Windows device object in Entra ID and matches it against the Windows Autopilot device identities in Intune. Devices that have no associated Autopilot object (matched via the Autopilot object's `azureActiveDirectoryDeviceId`) are reported as clean-up candidates.

Two Yes/No toggles control the output:

- **Send the report via email?** — when enabled, the recipient address field (`EmailTo`) is shown and the report is sent via email with the CSV attached.
- **Create a file download link?** — when enabled, the CSV is uploaded to an Azure Storage Account and a time-limited download link is returned.

Both can be combined or used independently. If both are disabled, the report is only printed to the runbook output.

## Setup regarding the storage account

The CSV report is uploaded to an Azure Storage Account. The target storage account is taken from the shared **RJReport** tenant settings, so it can be configured once and reused across all report runbooks:

- `RJReport.StorageAccount.ResourceGroup`
- `RJReport.StorageAccount.StorageAccountName`
- `RJReport.StorageAccount.LinkExpiryDays` (optional, defaults to 6)

The container name is configured per runbook (parameter `ContainerName`, default `windows-devices-without-autopilot`) and is intentionally not part of the global RJReport settings.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

The runbook's managed identity needs at least `Contributor` access on the subscription or resource group containing the storage account.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementServiceConfig.Read.All
  - Organization.Read.All
  - Mail.Send *(optional: Email report)*

### Permission notes
Azure IaaS: - Contributor - access on subscription or resource group used for the export


## Parameters
### SendMail
Send the report to the recipient email address.

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
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | windows-devices-without-autopilot |
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

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

