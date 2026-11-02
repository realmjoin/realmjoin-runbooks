# List Admin Users

List all Entra ID admins and check their MFA methods

## Detailed description
Lists every user and service principal that holds a built-in Entra ID role, including PIM eligible assignments, as an admin-to-role report. Optionally the registered authentication methods of each admin are checked to show who is protected by MFA, with a choice of which methods count. The report can be uploaded as CSV to an Azure Storage account. Nothing is changed.

## Where to find
Org \ Security \ List Admin Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - RoleAssignmentSchedule.Read.Directory
  - RoleManagement.Read.All
  - User.Read.All
  - UserAuthenticationMethod.Read.All *(optional: MFA state)*

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the CSV upload)


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
Storage container the report files are uploaded to. Taken from the tenant setting ListAdminsReport.Container, otherwise set per runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting ListAdminsReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting ListAdminsReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation
No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku
No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

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

### RJReportResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when ListAdminsReport.ResourceGroup is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when ListAdminsReport.StorageAccount.Name is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportSubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

