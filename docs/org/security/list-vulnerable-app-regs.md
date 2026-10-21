# List Vulnerable App Regs

List app registrations possibly affected by CVE-2021-42306

## Detailed description
Checks the key credentials of every app registration in Entra ID for signs of CVE-2021-42306, where private key material was stored in the credential by mistake. App registrations that may be affected are listed. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

## Where to find
Org \ Security \ List Vulnerable App Regs

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All


## Parameters
### ExportToFile
List in the run output, or export to a CSV file in the storage account configured in the tenant settings.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting VulnAppRegExport.Container.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting VulnAppRegExport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting VulnAppRegExport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting VulnAppRegExport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting VulnAppRegExport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

