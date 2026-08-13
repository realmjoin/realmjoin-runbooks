# Report Primary User Mismatch (Scheduled)

Compare primary user assignments in Intune against RealmJoin for Windows managed devices

## Detailed description
For Windows managed devices, this scheduled report compares the primary user recorded in Intune against the primary user recorded in the RealmJoin customer API. It correlates the two datasets per device, flags any device where the primary user differs, and emails the differences with CSV and/or Excel (xlsx) attachments.
The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

## Where to find
Org \ Devices \ Report Primary User Mismatch_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each) and a custom footer link. When these settings are not configured, the default RealmJoin graphics are used. A branding image that cannot be downloaded or validated never prevents the report email - the default graphic is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.

## Setup regarding RealmJoin API credentials

This runbook queries the RealmJoin customer API and requires a dedicated credential stored in the Azure Automation Account.

**Step-by-step setup:**

1. **Get API credentials** — If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
2. **Open the Automation Account** — In the Azure portal, navigate to the Automation Account used for runbooks
3. **Go to Shared Resources > Credentials** — In the left menu under *Shared Resources*, click *Credentials*
4. **Add a new credential** — Click *Add a credential*
5. **Name it exactly `RJAPI`** — The runbook looks up this name; any deviation will cause the credential lookup to fail
6. **Enter the RealmJoin API username and password** — Use the credentials from step 1
7. **Save** — Click *Create* and re-run the runbook


## Notes
Prerequisites:
- An Azure Automation Account shared credential named exactly "RJAPI" must be created manually
  before scheduling. Set the username and password to match a RealmJoin customer API account
  (see https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication).
- The Automation Account managed identity must have the following Graph application permissions
  assigned: DeviceManagementManagedDevices.Read.All, Mail.Send, Organization.Read.All.
- The RJReport.EmailSender setting must be configured with a valid sender address before the first run.
- No email is sent when the two datasets are in sync; an empty run is not an error.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All


## Parameters
### SyncThresholdDays
Number of days to look back for the Intune last-sync filter. Only Windows devices that have synced within this many days are evaluated.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### DeviceNamePrefix
Optional device name prefix to filter the report to a specific subset of devices. Leave blank to include all devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeMismatches
Include devices whose primary user differs between Intune and RealmJoin in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMissingInRealmJoin
Include devices that exist in Intune but have no matching device in RealmJoin in the report. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeMissingInIntune
Include devices that exist in RealmJoin but have no matching Intune device in the report. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludePrimaryUserDeleted
Include devices whose Intune primary user has been deleted from Entra ID in the report. Intune mangles the user principal name of a deleted user by prefixing its object id, which would otherwise show up as a false Mismatch. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### UseDeviceScope
Enable device scope filtering to include or exclude devices based on Entra device group membership.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeDeviceGroup
Only include devices that are members of this Entra device group in the report. Requires device scope filtering to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeDeviceGroup
Exclude devices that are members of this Entra device group from the report. Requires device scope filtering to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
If specified, an email with the report will be sent to the provided address(es). Can be a single address or multiple comma-separated addresses.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This is configured via the runbook customization setting and hidden in the portal.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink

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
| Default Value | report-primary-user-mismatch |
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


[Back to Table of Content](../../../README.md)

