# List Signin Events

Retrieve and analyze sign-in events for a target user

## Detailed description
Retrieves the target user's Entra ID sign-in logs from the Microsoft Graph beta endpoint and analyzes them: each sign-in's application, timestamp, status (with error codes and failure reasons if applicable), client app, device and location information is displayed, and a per-application failure summary helps support teams identify which applications are experiencing issues and diagnose the underlying causes. IP addresses are shown in the failed sign-in view; conditional access details are included in the exported report files. The runbook can optionally export the full data set to CSV and XLSX files and deliver them by email and/or a time-limited download link.

## Where to find
User \ Security \ List Signin Events

## Required license and permissions

Reading sign-in logs through the Microsoft Graph API requires an **Entra ID P1 or P2 license** in the tenant. Tenants without it receive a 403 error from the sign-in log query even when all Graph permissions are granted. With P1/P2, sign-in logs are retained for up to 30 days; the 7-day retention of the free tier applies to the Entra portal, not to this runbook.

If the sign-in log query returns a 403 although `AuditLog.Read.All` is granted and the tenant is licensed, some tenants additionally require `Directory.Read.All` on the Entra reporting API. Granting it is the known workaround; it is not declared by default because it grants read access to every directory object.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *No report* selected, the sign-in analysis is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.

## Interpreting the results

Entra counts some sign-in interrupts as errors (for example 50140 "Keep me signed in", 50058 and 50076), so they appear as failures and are included in the per-application failure rate. Check the failure reason before treating a high failure rate as a genuine problem. Error codes are Entra ID sign-in error codes; look them up at [https://login.microsoftonline.com/error](https://login.microsoftonline.com/error).

Sign-in log data typically lags ~15 minutes but can take up to 2 hours for some records - a very recent sign-in may not yet appear. All timestamps are shown in UTC.


## Notes
Common Use Cases:
- Investigate which application is generating sign-in failures for a specific user and why (grouped by error code).
- Narrow results with ApplicationName (partial match) or FailedSignInsOnly when a user reports access issues.
- Export sign-in data to CSV/XLSX for further analysis in Excel when the event count is too large to read in the portal.

Behavior:
- Sign-in log data is retrieved from the Microsoft Graph beta endpoint because sign-in event type filtering
  and non-interactive sign-in retrieval require beta-only properties (signInEventTypes, authenticationRequirement).
- Non-interactive sign-ins vastly outnumber interactive ones; the console detail tables are capped at the
  50 most recent entries, but exported report files always contain the full result set.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Days
Number of days to retrieve sign-in logs for (1 to 30 days). Default is 7 days.

| Property | Value |
|----------|-------|
| Default Value | 7 |
| Required | false |
| Type | Int32 |

### SignInType
Filter sign-in events by type: Interactive only, Non-interactive only, or both.

| Property | Value |
|----------|-------|
| Default Value | Interactive only |
| Required | false |
| Type | String |

### FailedSignInsOnly
If set to true, only failed sign-in attempts are displayed. If false, all sign-in events are shown.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ApplicationName
Optional filter to display sign-ins for a specific application only (partial match). Leave empty to include all applications.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. Sourced from the RJReport.EmailSender tenant setting. This needs to be configured in the runbook customization.

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

### SendEmailReport
If set to true, the sign-in report will be sent by email. If false, no email is sent.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient email address(es) for the report. Can be a single address or multiple comma-separated addresses.
Emails are sent individually to each recipient.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Select the report file format: CSV & XLSX (both files), CSV only, or XLSX only. Only used when a delivery method (email or download link) is selected.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
If set to true, the report files will be uploaded to Azure Storage and a time-limited download link will be generated. If false, no upload occurs.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | user-signin-events |
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
Number of days until the generated download link expires (1 to 3650 days). Sourced from the RJReport tenant settings. Default is 6 days.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

