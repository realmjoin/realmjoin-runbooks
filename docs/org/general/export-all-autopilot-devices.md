# Export All Autopilot Devices

List or export all Windows Autopilot devices

## Detailed description
Lists all Windows Autopilot devices and optionally exports them to a CSV file in Azure Storage. If exporting is enabled, the runbook uploads the report and returns a time-limited SAS (download) link.

## Where to find
Org \ General \ Export All Autopilot Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All


## Parameters
### ExportToFile
"List in Console" (final value: $false) or "Export to a CSV file" (final value: $true) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Name of the Azure Storage container to upload the CSV report to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Name of the Azure Resource Group containing the Storage Account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Name of the Azure Storage Account used for upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region for the Storage Account if it needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
SKU name for the Storage Account if it needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

