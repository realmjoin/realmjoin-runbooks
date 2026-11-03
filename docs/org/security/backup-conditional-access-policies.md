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
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys


## Parameters
### ContainerName
Storage container the archive is uploaded to. Taken from the tenant setting CaPoliciesExport.Container; empty means a container named after the current date.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for the backup. Taken from the tenant setting CaPoliciesExport.ResourceGroup; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the backup. Taken from the tenant setting CaPoliciesExport.StorageAccount.Name; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportResourceGroupName
Resource group of the storage account for the backup. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when neither CaPoliciesExport.ResourceGroup nor the Automation variable SettingsExports sets one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for the backup. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when neither CaPoliciesExport.StorageAccount.Name nor the Automation variable SettingsExports sets one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportSubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

