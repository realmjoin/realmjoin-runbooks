# Monitor Pending EPM Requests (Scheduled)

Monitor and report pending Endpoint Privilege Management (EPM) elevation requests

## Detailed description
Queries Microsoft Intune for pending EPM elevation requests and sends an email report.
Email is only sent when there are pending requests.
Optionally includes detailed information about each request in a table and report file attachments.
The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

## Where to find
Org \ Security \ Monitor Pending EPM Requests_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.


## Notes
Runbook Type: Scheduled (recommended: hourly or every 1 hours)

Endpoint Privilege Management (EPM) Context:
- EPM allows users to request temporary admin rights for specific applications
- Pending requests require manual review and approval by security admins
- Requests expire automatically if not reviewed within the configured timeframe
- Timely review is critical for user productivity and security posture

Email Behavior:
- Emails are sent individually to each recipient
- No email is sent when there are zero pending requests
- Report file attachments (see ReportFileFormat) are only included when DetailedReport is enabled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Mail.Send


## Parameters
### DetailedReport
When enabled, includes detailed request information in a table and as report file attachment(s).
When disabled, only provides a summary count of pending requests.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

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
| Default Value | monitor-pending-epm-requests |
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

