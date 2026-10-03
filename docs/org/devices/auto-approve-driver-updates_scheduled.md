# Auto Approve Driver Updates (Scheduled)

Approve pending driver updates in Intune driver update policies

## Detailed description
Approves driver updates that are waiting for review in Intune driver update policies, so drivers roll out without manual approval. The scope can be narrowed to certain policies, driver names, classes, manufacturers or a maximum driver age, and a dry run shows what would be approved. The report of all approvals can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ Auto Approve Driver Updates_Scheduled

## Common use cases

- Test the filters first: use the `WhatIf` parameter to preview which drivers would be approved.
- Auto-approve all drivers: run without any filter parameter.
- Approve specific manufacturers: use `DriverManufacturer` to target vendors such as "Intel" or "AMD".
- Target specific policies: use `PolicyNames` or `PolicyIds` to scope the run to test policies first.
- Monitor the approvals: configure `EmailTo` to receive a detailed report after each run.

## Parameter interactions

- Without a policy filter, all driver update policies are processed.
- Without a driver filter, all pending drivers of the selected policies are approved.
- `PolicyNames` and `PolicyIds` can be combined; both filters apply independently.
- `WhatIf` simulates the approvals without making changes, which is useful for testing the filters.

## Prerequisites

The driver update endpoints are only available on the Microsoft Graph beta API, which this runbook uses.

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All


## Parameters
### PolicyNames
Only these driver update policies, separated by commas. Leave empty for all policies.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PolicyIds
Only these policy IDs, separated by commas. Leave empty for all policies.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverDisplayNamePattern
Only drivers whose name matches this pattern; wildcards such as * are allowed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverClass
Only these driver classes, separated by commas, for example Bluetooth,Networking,Firmware.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverManufacturer
Only drivers from this manufacturer.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MaximumDriverAge
Only drivers released within this many days, for example 30. Leave empty for any age.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### OnlyNeedsReview
Approves only drivers with the status "needs review". Turn off to also re-approve suspended or declined drivers.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### WhatIf
Only shows which drivers would be approved and sends the report; nothing is approved.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | SwitchParameter |

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
| Default Value | auto-approve-driver-updates |
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

### EmailTo
Send the approval report to these addresses, separated by commas. Leave empty to send no email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

