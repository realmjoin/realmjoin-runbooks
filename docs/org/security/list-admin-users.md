# List Admin Users

List Entra ID role holders and optionally evaluate their MFA methods

## Detailed description
Lists users and service principals holding built-in Entra ID roles and produces an admin-to-role report. Optionally queries each admin for registered authentication methods to assess MFA coverage.

## Where to find
Org \ Security \ List Admin Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All


## Parameters
### ExportToFile
If set to true, exports the report to an Azure Storage Account.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### PimEligibleUntilInCSV
If set to true, includes PIM eligible until information in the CSV report.

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

### QueryMfaState
"Check and report every admin's MFA state" (final value: $true) or "Do not check admin MFA states" (final value: $false) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustEmailMfa
If set to true, regards email as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustPhoneMfa
If set to true, regards phone/SMS as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustSoftwareOathMfa
If set to true, regards software OATH token as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustWinHelloMFA
If set to true, regards Windows Hello for Business as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

