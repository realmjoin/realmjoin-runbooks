# Backup Conditional Access Policies

Back up all Conditional Access policies to Azure Storage

## Detailed description
Exports every Conditional Access policy of the tenant as JSON and uploads them as one ZIP archive to an Azure Storage account. The backup lets you compare or restore policies later. Without a container name, a container named after the current date is used. Nothing is changed in the tenant.

## Where to find
Org \ Security \ Backup Conditional Access Policies

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Policy.Read.All

### Permission notes
Azure IaaS: Access to the given Azure Storage Account / Resource Group


## Parameters
### ContainerName
Storage container the archive is uploaded to. Taken from the tenant setting CaPoliciesExport.Container; empty means a container named after the current date.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting CaPoliciesExport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the backup. Taken from the tenant setting CaPoliciesExport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

