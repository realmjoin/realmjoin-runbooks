# List Vulnerable App Regs

List app registrations possibly affected by CVE-2021-42306

## Detailed description
Checks the key credentials of every app registration in Entra ID for signs of CVE-2021-42306, where private key material was stored in the credential by mistake. App registrations that may be affected are listed; those whose credentials cannot be read are named as not checked. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

## Where to find
Org \ Security \ List Vulnerable App Regs

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the CSV export)


## Parameters
### ExportToFile
List in the run output, or export to a CSV file in the storage account configured in the tenant settings.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting VulnAppRegExport.Container, otherwise set per runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting VulnAppRegExport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting VulnAppRegExport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

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
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when VulnAppRegExport.ResourceGroup is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when VulnAppRegExport.StorageAccount.Name is not set.

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

