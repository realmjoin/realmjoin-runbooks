# Export All Intune Devices

Export all Intune devices with their primary users' usage location

## Detailed description
Exports every Intune managed device together with details of its primary user, such as the usage location, as a CSV file to an Azure Storage account. Optionally only devices whose primary user is in a given group are exported. Nothing is changed.

## Where to find
Org \ General \ Export All Intune Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - GroupMember.Read.All
  - Group.Read.All


## Parameters
### ContainerName
Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Azure subscription that holds the storage account. Taken from the tenant setting IntuneDevicesReport.SubscriptionId.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### FilterGroupID
Only devices whose primary user is in this group. Leave empty for all devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

