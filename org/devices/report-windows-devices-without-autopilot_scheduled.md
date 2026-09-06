## Reporting orphaned Windows devices

This runbook lists every Windows device object in Entra ID and matches it against the Windows Autopilot device identities in Intune. Devices that have no associated Autopilot object (matched via the Autopilot object's `azureActiveDirectoryDeviceId`) are reported as clean-up candidates ("Objektleichen").

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
