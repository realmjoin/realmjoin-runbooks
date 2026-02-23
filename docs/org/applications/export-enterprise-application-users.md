# Export Enterprise Application Users

Export a CSV of all (enterprise) application owners and users

## Detailed description
This runbook exports a CSV report of enterprise applications (or all service principals) including owners and assigned users or groups.
It uploads the generated CSV file to an Azure Storage Account and returns a time-limited download link.

## Where to find
Org \ Applications \ Export Enterprise Application Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Application.Read.All

### Permission notes
Azure IaaS: - Contributor - access on subscription or resource group used for the export


## Parameters
### entAppsOnly
Determines whether to export only enterprise applications (final value: true) or all service principals/applications (final value: false).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload.

| Property | Value |
|----------|-------|
| Default Value |  |
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
Storage account name used for the upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region for the storage account, used when the account needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Storage account SKU, used when the account needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

