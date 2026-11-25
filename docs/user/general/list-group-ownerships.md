# List Group Ownerships

List the groups this user owns

## Detailed description
Lists the Entra ID groups this user owns, with their names, IDs and type (Microsoft 365, security or distribution). Every run shows the list as Output Data tables in the portal. Nothing is changed. The report can be sent by email or provided as a download link.

## Where to find
User \ General \ List Group Ownerships

## Output Data and report delivery

Every run writes the result as Output Data tables, which can be sorted, filtered and exported in the RealmJoin portal:

- **Summary** - the number of groups the user owns, in total and per group type.
- **Group Ownerships** - one row per owned group with `DisplayName`, `ID` and `Type` (`M365`, `Security`, `Distribution` or `Other`), the same rows and columns as the report files. When the user owns no groups, a status line is shown instead.

The **Report delivery** option adds report files on top:

- **Output Data only** (default) - no report files.
- **Also email the report** - the recipient address field (`EmailTo`) is shown and required, and the report is sent via email with the report file(s) attached.
- **Also create a download link** - the report file(s) are uploaded to an Azure Storage Account and a time-limited download link is returned.
- **Also email & download link** - both.

**Report file format** chooses CSV, XLSX or both for the report files. Report files are only created when the user owns at least one group.

The option sets the parameters `SendMail` and `CreateDownloadLink`. Schedules and API calls that pass these parameters directly keep working as before. A schedule saved before the option existed opens with *Output Data only* selected but keeps its stored delivery until another option is chosen.

## Setup regarding the storage account

For the download link, the report files are uploaded to the Azure Storage Account configured in the shared `RJReport.StorageAccount.*` tenant settings (`ResourceGroup`, `StorageAccountName`, optionally `SubscriptionId` and `LinkExpiryDays`). The container name is configured per runbook (parameter `ContainerName`, default `user-group-ownerandmemberships`). The managed identity of the Automation Account needs the `Reader and Data Access` role on the storage account.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

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
  - Group.Read.All
  - Organization.Read.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### SendMail
Send the report to the recipient email address. Set by the "Report delivery" selection; schedules and API calls can pass it directly.

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
Also upload the report and return a download link that expires after a few days. Set by the "Report delivery" selection; schedules and API calls can pass it directly.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | user-group-ownerandmemberships |
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

### SubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

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

