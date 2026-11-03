# List Inactive Devices

List devices with no recent sign-in or Intune sync

## Detailed description
Lists the devices whose last Intune sync, or whose last sign-in recorded in Entra ID, is older than the chosen number of days. The result is shown in the Output Data tables of the run and can also be exported as a CSV file to an Azure Storage account. Nothing is changed.

## Where to find
Org \ Security \ List Inactive Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the CSV export)


## Parameters
### Days
Devices with no sync or sign-in for at least this many days are listed.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### Sync
Last Intune sync looks at managed devices and their last check-in; Last sign-in looks at Entra ID device objects and their approximate last sign-in date.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ExportToFile
The list is always shown in the Output Data tables of the run. "Also export to a CSV file" also uploads it as a CSV file to the storage account configured in the tenant settings and returns a download link.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting InactiveDevices.Container, otherwise set per runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting InactiveDevices.ResourceGroup; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting InactiveDevices.StorageAccount.Name; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.StorageAccountName.

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

### RJReportResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when neither InactiveDevices.ResourceGroup nor the Automation variable SettingsExports sets one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when neither InactiveDevices.StorageAccount.Name nor the Automation variable SettingsExports sets one.

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

