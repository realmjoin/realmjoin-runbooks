# List Signin Events

Show the recent sign-ins of this user and their failures

## Detailed description
Lists the Entra ID sign-ins of this user for the chosen number of days with application, time, result, client app, device and location. Failures are summed up per application so support can see where sign-ins go wrong, and failed sign-ins also show the IP address. The report can be sent by email or provided as a download link.

## Where to find
User \ Security \ List Signin Events

## Common use cases

- Investigate which application generates sign-in failures for a specific user and why, grouped by error code.
- Narrow the results with `ApplicationName` (partial match) or `FailedSignInsOnly` when a user reports access issues.
- Export the sign-in data to CSV or Excel for further analysis when the event count is too large to read in the portal.

## Behaviour

- Sign-in log data is retrieved from the Microsoft Graph beta endpoint, because sign-in event type filtering and the retrieval of non-interactive sign-ins require beta-only properties (`signInEventTypes`, `authenticationRequirement`).
- Non-interactive sign-ins vastly outnumber interactive ones; the console detail tables are capped at the 50 most recent entries, but the exported report files always contain the full result set.

## Required license and permissions

Reading sign-in logs through the Microsoft Graph API requires an **Entra ID P1 or P2 license** in the tenant. Tenants without it receive a 403 error from the sign-in log query even when all Graph permissions are granted. With P1/P2, sign-in logs are retained for up to 30 days; the 7-day retention of the free tier applies to the Entra portal, not to this runbook.

If the sign-in log query returns a 403 although `AuditLog.Read.All` is granted and the tenant is licensed, some tenants additionally require `Directory.Read.All` on the Entra reporting API. Granting it is the known workaround; it is not declared by default because it grants read access to every directory object.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *No report* selected, the sign-in analysis is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Interpreting the results

Entra counts some sign-in interrupts as errors (for example 50140 "Keep me signed in", 50058 and 50076), so they appear as failures and are included in the per-application failure rate. Check the failure reason before treating a high failure rate as a genuine problem. Error codes are Entra ID sign-in error codes; look them up at [https://login.microsoftonline.com/error](https://login.microsoftonline.com/error).

Sign-in log data typically lags ~15 minutes but can take up to 2 hours for some records - a very recent sign-in may not yet appear. All timestamps are shown in UTC.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Days
How many days of sign-in logs to include, 1 to 30.

| Property | Value |
|----------|-------|
| Default Value | 7 |
| Required | false |
| Type | Int32 |

### SignInType
Interactive sign-ins by the user, non-interactive ones by apps and tokens, or both.

| Property | Value |
|----------|-------|
| Default Value | Interactive only |
| Required | false |
| Type | String |

### FailedSignInsOnly
Hides successful sign-ins so the failures and their reasons stand out.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ApplicationName
Shows only sign-ins to applications whose name contains this text. Leave empty for all applications.

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

### SendEmailReport
Whether the report is sent by email. Preset in the runbook customization.

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
| Default Value | user-signin-events |
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

