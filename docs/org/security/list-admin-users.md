# List Admin Users

List all Entra ID admins and check their MFA methods

## Detailed description
Lists every user and service principal that holds a built-in Entra ID role, including PIM eligible assignments, as an admin-to-role report. Optionally the registered authentication methods of each admin are checked to show who is protected by MFA, with a choice of which methods count. The report can be uploaded as CSV to an Azure Storage account. Nothing is changed.

## Where to find
Org \ Security \ List Admin Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All
  - RoleAssignmentSchedule.Read.Directory
  - UserAuthenticationMethod.Read.All *(optional: MFA state)*


## Parameters
### ExportToFile
Uploads the report as CSV to the storage account configured in the tenant settings.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### PimEligibleUntilInCSV
Adds the end dates of PIM eligible and active assignments to the CSV report.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting ListAdminsReport.Container.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account. Taken from the tenant setting ListAdminsReport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting ListAdminsReport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
Azure region used when the storage account has to be created. Taken from the tenant setting ListAdminsReport.StorageAccount.Location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
Performance tier used when the storage account has to be created. Taken from the tenant setting ListAdminsReport.StorageAccount.Sku.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### QueryMfaState
With the check, each admin gets a column showing whether a method that counts as MFA is registered; without it, the report lists only the role assignments.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustEmailMfa
Counts email as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustPhoneMfa
Counts phone calls and SMS as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustSoftwareOathMfa
Counts software OATH tokens as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustWinHelloMFA
Counts Windows Hello for Business as a valid MFA method.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

