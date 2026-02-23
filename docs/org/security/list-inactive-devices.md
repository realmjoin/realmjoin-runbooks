# List Inactive Devices

List or export inactive devices with no recent logon or Intune sync

## Detailed description
Collects devices based on either last interactive sign-in or last Intune sync date and lists them in the console. Optionally exports the results to a CSV file in Azure Storage.

## Where to find
Org \ Security \ List Inactive Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All


## Parameters
### Days
Number of days without sync or sign-in used to consider a device inactive.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### Sync
If set to true, inactivity is based on last Intune sync; otherwise it is based on last interactive sign-in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ExportToFile
If set to true, exports the results to a CSV file in Azure Storage.

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

