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
