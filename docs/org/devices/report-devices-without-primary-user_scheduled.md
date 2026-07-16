# Report Devices Without Primary User (Scheduled)

Reports all managed devices in Intune that do not have a primary user assigned.

## Detailed description
This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
The output is a formatted table showing Object ID, Device ID, Display Name, Operating System, and Last Sync Date/Time for each device without a primary user.
The report can be limited to specific platforms (Windows, macOS, iOS/iPadOS, Android, Other) via boolean parameters. By default, all platforms are included.

Optionally, the report can be sent via email with CSV and Excel (xlsx) attachments containing detailed device information.
The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.

## Where to find
Org \ Devices \ Report Devices Without Primary User_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Mail.Send


## Parameters
### IncludeWindows
Include Windows devices in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMacOS
Include macOS devices in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeIOS
Include iOS and iPadOS devices in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeAndroid
Include Android devices in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeOther
Include devices with any other operating system (e.g. Linux, ChromeOS) in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### CreateDownloadLink
If enabled, the report CSV is uploaded to an Azure Storage Account and a time-limited download link is returned. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | devices-without-primary-user |
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

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

