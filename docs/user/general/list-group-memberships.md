# List Group Memberships

List the group memberships of this user

## Detailed description
Lists the groups this user is a member of, with filters for group type, membership type, role assignability, Teams, source and writeback. The result is shown as CSV text and as Output Data tables. The report can also be sent by email or provided as a download link. Nothing is changed.

## Where to find
User \ General \ List Group Memberships

## Output and report delivery

Every run lists the matching groups as CSV text in the runbook output and writes two Output Data tables, which can be sorted, filtered and exported in the RealmJoin portal:

- `Summary` - the user, the selected filters, the number of direct group memberships and the number of groups matching the filters.
- `Group Memberships` - one row per matching group with the same columns as the CSV file and the `Group Memberships` worksheet. When no group matches, a status line is shown instead.

The **Report delivery** option adds report files on top:

- **Output Data only** (default) - no report files.
- **Also email the report** - the recipient address field (`EmailTo`) is shown and required, and the report is sent via email with the report file(s) attached.
- **Also create a download link** - the report file(s) are uploaded to an Azure Storage Account and a time-limited download link is returned.
- **Also email & download link** - both.

**Report file format** chooses CSV, XLSX or both for the report files. When no group matches the filters, no report files are created, uploaded or emailed.

The option sets the parameters `SendMail` and `CreateDownloadLink`. Schedules and API calls that pass these parameters directly keep working as before.

## Setup regarding the storage account

For the download link, the report files are uploaded to an Azure Storage Account. The target storage account is taken from the shared **RJReport** tenant settings, so it can be configured once and reused across all report runbooks:

- `RJReport.StorageAccount.ResourceGroup`
- `RJReport.StorageAccount.StorageAccountName`
- `RJReport.StorageAccount.SubscriptionId` (optional, recommended; see [Subscription of the Storage Account](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#subscription-of-the-storage-account))
- `RJReport.StorageAccount.LinkExpiryDays` (optional, defaults to 6)

The container name is configured per runbook (parameter `ContainerName`, default `user-group-memberships`). The managed identity of the Automation Account needs the `Reader and Data Access` role on the storage account.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery (parameter `SendMail`); a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

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

### GroupType
Security groups only, Microsoft 365 groups only, or all groups.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### MembershipType
Assigned memberships, dynamic memberships, or all.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### RoleAssignable
Yes limits the list to groups that can be assigned Entra ID roles.

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### TeamsEnabled
Yes limits the list to groups that back a Microsoft Teams team.

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### Source
Cloud-only groups, groups synchronized from on-premises Active Directory, or all.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### WritebackEnabled
Groups with writeback to on-premises Active Directory, groups without, or all.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### SendMail
Send the report to the recipient email address. Set from the "Report delivery" choice in the portal.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email. Required when "Report delivery" includes an email.

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
Deliver the report as CSV, as an Excel workbook, or both. Shown when "Report delivery" includes an email or a download link.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days. Set from the "Report delivery" choice in the portal.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | user-group-memberships |
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

