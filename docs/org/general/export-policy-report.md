# Export Policy Report

Export Intune and Entra ID policies as a Markdown report

## Detailed description
Collects the configuration policies from Intune and Entra ID and writes them into one Markdown report, for documentation or review. The raw policy definitions can be exported as JSON as well. The files can be uploaded to an Azure Storage account with time-limited download links. Nothing is changed.

## Where to find
Org \ General \ Export Policy Report

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Policy.Read.All
  - Directory.Read.All *(optional: Name resolution)*

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys


## Parameters
### produceLinks
Uploads the report files to the storage account configured in the tenant settings and returns download links.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportJson
Also exports the raw policy definitions as JSON files.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### renderLatexPagebreaks
Adds LaTeX page breaks to the Markdown, so each policy starts on a new page when the Markdown is converted to PDF.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting TenantPolicyReport.Container, otherwise set per runbook.

| Property | Value |
|----------|-------|
| Default Value | export-policy-report |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting TenantPolicyReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting TenantPolicyReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

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
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when TenantPolicyReport.ResourceGroup is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when TenantPolicyReport.StorageAccount.Name is not set.

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

