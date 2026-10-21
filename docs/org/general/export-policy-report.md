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
Azure Storage Account: Contributor role on the Storage Account used for exporting reports


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
Storage container the report files are uploaded to. Taken from the tenant setting TenantPolicyReport.Container.

| Property | Value |
|----------|-------|
| Default Value | rjrb-licensing-report-v2 |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting TenantPolicyReport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting TenantPolicyReport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting TenantPolicyReport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting TenantPolicyReport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

