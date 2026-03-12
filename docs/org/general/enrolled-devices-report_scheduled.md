# Enrolled Devices Report (Scheduled)

Show recent first-time device enrollments

## Detailed description
This runbook reports recent device enrollments based on a configurable time range.
It can group results by a selected attribute and can optionally export the report as a CSV file.

## Where to find
Org \ General \ Enrolled Devices Report_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.Read.All
  - DeviceManagementManagedDevices.Read.All
  - User.Read.All
  - Device.ReadWrite.All

### Permission notes
Azure: Contributor on Storage Account


## Parameters
### Weeks
Time range in weeks to include in the report.

| Property | Value |
|----------|-------|
| Default Value | 4 |
| Required | false |
| Type | Int32 |

### dataSource
Data source used to determine the first enrollment date.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### groupingSource
Data source used to resolve the grouping attribute.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### groupingAttribute
Attribute name used for grouping.

| Property | Value |
|----------|-------|
| Default Value | country |
| Required | false |
| Type | String |

### exportCsv
Please configure an Azure Storage Account to use this feature.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region for the storage account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Storage account SKU.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

