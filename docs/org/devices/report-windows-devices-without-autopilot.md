# Report Windows Devices Without Autopilot

Reports all Windows Entra devices that have no associated Windows Autopilot object.

## Detailed description
This runbook lists every Windows device object in Entra ID (Microsoft Entra) and matches it against
the Windows Autopilot device identities in Intune. Entra devices whose device ID is not referenced by
any Autopilot object (via the Autopilot object's azureActiveDirectoryDeviceId) are reported as orphans.

Such orphaned Entra device objects are typical leftovers ("Objektleichen") from devices that were
reset, re-imaged, or replaced without being cleaned up. The report supports clean-up efforts by making
these candidates visible so they can be reviewed and - if appropriate - deleted.

Optionally, the report CSV can be uploaded to an Azure Storage Account (returning a time-limited
download link) and/or sent via email with the CSV attached.

## Where to find
Org \ Devices \ Report Windows Devices Without Autopilot

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

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

The runbook's managed identity needs at least `Contributor` access on the subscription or resource group containing the storage account.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementServiceConfig.Read.All
  - Organization.Read.All
  - Mail.Send

### Permission notes
Azure IaaS: - Contributor - access on subscription or resource group used for the export


## Parameters
### SendMail
If enabled, the report is sent via email. Toggling this on reveals the recipient address field.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient address(es) for the email report. Only used / shown when SendMail is enabled.
Can be a single address or multiple comma-separated addresses (string).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. Sourced from the RJReport tenant settings (RJReport.EmailSender).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateDownloadLink
If enabled, the report CSV is uploaded to an Azure Storage Account and a time-limited download link is returned.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | windows-devices-without-autopilot |
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

