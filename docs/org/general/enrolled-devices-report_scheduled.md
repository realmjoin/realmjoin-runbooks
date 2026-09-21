# Enrolled Devices Report (Scheduled)

Report first-time device enrollments of the last weeks

## Detailed description
Lists devices that enrolled for the first time within the chosen number of weeks. They are grouped by an attribute of your choice, such as country or department, so you can see where new devices show up. The report can be exported as CSV to an Azure Storage account and downloaded from there.

## Where to find
Org \ General \ Enrolled Devices Report_Scheduled

## Configure the storage account for the CSV export

The CSV export uploads the report to an Azure Storage account. Its resource group, name, region and performance tier come from the tenant settings below; the container name is taken from `EnrolledDevicesReport.Container`.

```json
{
  "Settings": {
    "EnrolledDevicesReport": {
      "ResourceGroup": "rj-test-runbooks-01",
      "StorageAccount": {
        "Name": "rjrbexports01",
        "Location": "West Europe",
        "Sku": "Standard_LRS"
      }
    }
  }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


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
How many weeks back to look for first enrollments.

| Property | Value |
|----------|-------|
| Default Value | 4 |
| Required | false |
| Type | Int32 |

### dataSource
Date of Autopilot profile assignment counts a device from the day its Autopilot profile was assigned, Date of Intune enrollment from the day it enrolled in Intune.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### groupingSource
Where the grouping attribute comes from: no grouping, Entra ID user or device properties, Intune device properties, or Autopilot device properties.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### groupingAttribute
Name of the attribute the devices are grouped by, for example country or department.

| Property | Value |
|----------|-------|
| Default Value | country |
| Required | false |
| Type | String |

### exportCsv
Uploads the report as CSV to the storage account and returns a download link. Needs a configured storage account.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report is uploaded to. Taken from the tenant setting EnrolledDevicesReport.Container.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting EnrolledDevicesReport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

