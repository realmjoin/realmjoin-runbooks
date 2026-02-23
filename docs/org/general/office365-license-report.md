# Office365 License Report

Generate an Office 365 licensing report

## Detailed description
This runbook creates a licensing report based on Microsoft 365 subscription SKUs and optionally includes Exchange Online related reports.
It can export the results to Azure Storage and generate SAS links for downloads.

## Where to find
Org \ General \ Office365 License Report

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Reports.Read.All
  - Directory.Read.All
  - User.Read.All


## Parameters
### printOverview
If set to true, prints a short license usage overview.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### includeExhange
If set to true, includes Exchange Online related reports.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### exportToFile
If set to true, exports reports to Azure Storage when configured.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportAsZip
If set to true, exports reports as a single ZIP file.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### produceLinks
If set to true, creates SAS tokens/links for exported artifacts.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for uploads.

| Property | Value |
|----------|-------|
| Default Value | rjrb-licensing-report-v2 |
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
Storage account name used for uploads.

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

### SubscriptionId
Azure subscription ID used for storage operations.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

