# Export Policy Report

Create a report of tenant policies from Intune and Entra ID.

## Detailed description
This runbook exports configuration policies from Intune and Entra ID and writes the results to a Markdown report.
It can optionally export raw JSON and create downloadable links for exported artifacts.

## Where to find
Org \ General \ Export Policy Report

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Policy.Read.All

### Permission notes
Azure Storage Account: Contributor role on the Storage Account used for exporting reports


## Parameters
### produceLinks
If set to true, creates links for exported artifacts based on settings.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportJson
If set to true, also exports raw JSON policy payloads.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### renderLatexPagebreaks
If set to true, adds LaTeX page breaks to the generated Markdown.

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


[Back to Table of Content](../../../README.md)

