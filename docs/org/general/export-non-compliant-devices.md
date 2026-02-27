# Export Non Compliant Devices

Export non-compliant Intune devices and settings

## Detailed description
This runbook queries Intune for non-compliant and in-grace-period devices and retrieves detailed policy and setting compliance data.
It can export the results to CSV with SAS (download) links.

## Where to find
Org \ General \ Export Non Compliant Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All

### Permission notes
Azure IaaS: Access to create/manage Azure Storage resources if producing links


## Parameters
### produceLinks
If set to true, uploads artifacts and produces SAS (download) links when storage settings are available.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for uploads.

| Property | Value |
|----------|-------|
| Default Value | rjrb-device-compliance-report-v2 |
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

