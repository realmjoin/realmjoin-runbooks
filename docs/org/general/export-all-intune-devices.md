# Export All Intune Devices

Export a list of all Intune devices and where they are registered

## Detailed description
Exports all Intune managed devices and enriches them with selected owner metadata such as usage location. The report is uploaded as a CSV file to an Azure Storage container.

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

### SubscriptionId
Optional Azure Subscription Id to set the context for Storage Account operations.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### FilterGroupID
Optional group filter (ObjectId). When specified, only devices whose primary owner is a member of this group are exported.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

