# List Vulnerable App Regs

List app registrations potentially vulnerable to CVE-2021-42306

## Detailed description
Lists Azure AD app registrations that may be affected by CVE-2021-42306 by inspecting stored key credentials. Optionally exports the findings to a CSV file in Azure Storage.

## Where to find
Org \ Security \ List Vulnerable App Regs

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All


## Parameters
### ExportToFile
"List in Console" (final value: $false) or "Export to a CSV file" (final value: $true) can be selected as action to perform. The export saves the findings to a CSV file in Azure Storage.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Name of the Azure Storage container to upload the CSV report to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Name of the Azure Resource Group containing the Storage Account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Name of the Azure Storage Account used for upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region for the Storage Account if it needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
SKU name for the Storage Account if it needs to be created.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

