## Reporting Windows devices without an Autopilot object

This runbook lists every Windows device object in Entra ID and matches it against the Windows Autopilot device identities in Intune. Devices that have no associated Autopilot object (matched via the Autopilot object's `azureActiveDirectoryDeviceId`) are reported with their join type.

The `JoinType` column, the last column of the report, is derived from the device object's `trustType`:

- **Entra joined** (`AzureAd`) - objects without an Autopilot object are typically left over from devices that were reset, re-imaged or replaced without cleanup. These are the clean-up candidates; review them before you delete them.
- **Hybrid joined** (`ServerAd`) - domain joined devices synchronized to Entra ID. They show up whenever no Autopilot object refers to their device object, but are usually in use and not orphaned.
- **Entra registered** (`Workplace`) - personal or BYOD devices registered by a user. They are usually in use and not orphaned.

Do not delete hybrid joined or Entra registered devices because of this report alone.

Every run writes the result as Output Data tables (`Summary` and `Devices`), which can be sorted, filtered and exported in the RealmJoin portal. The **Report delivery** option adds report files on top:

- **Output Data only** - no report files.
- **Also email the report** - the recipient address field (`EmailTo`) is shown and the report is sent via email with the report file(s) attached.
- **Also create a download link** (default) - the report file(s) are uploaded to an Azure Storage Account and a time-limited download link is returned.
- **Also email & download link** - both.

**Report file format** chooses CSV, XLSX or both for the report files.

## Setup regarding the storage account

The CSV report is uploaded to an Azure Storage Account. The target storage account is taken from the shared **RJReport** tenant settings, so it can be configured once and reused across all report runbooks:

- `RJReport.StorageAccount.ResourceGroup`
- `RJReport.StorageAccount.StorageAccountName`
- `RJReport.StorageAccount.SubscriptionId` (optional, recommended; see [Subscription of the Storage Account](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#subscription-of-the-storage-account))
- `RJReport.StorageAccount.LinkExpiryDays` (optional, defaults to 6)

The container name is configured per runbook (parameter `ContainerName`, default `windows-devices-without-autopilot`) and is intentionally not part of the global RJReport settings.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

The managed identity of the Automation Account needs the `Reader and Data Access` role on the storage account.

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
