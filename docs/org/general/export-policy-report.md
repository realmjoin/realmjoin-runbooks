# Export Policy Report

Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

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

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportJson

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### renderLatexPagebreaks

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName

| Property | Value |
|----------|-------|
| Default Value | rjrb-licensing-report-v2 |
| Required | false |
| Type | String |

### ResourceGroupName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

