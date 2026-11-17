# Enrolled Devices Report (Scheduled)

Report recent first-time enrollments of Windows Autopilot devices

## Detailed description
Lists Windows devices registered in Autopilot that enrolled for the first time within the chosen number of weeks. They are grouped by an attribute of your choice, such as country or department, so you can see where new devices show up. iOS, Android and macOS devices and Windows devices enrolled without Autopilot are not included. The report can be exported as CSV to an Azure Storage account and downloaded from there.

## Where to find
Org \ General \ Enrolled Devices Report_Scheduled

## Which devices are included

The report starts from the Windows Autopilot device identities in Intune, so it lists only Windows devices registered in Autopilot. iOS, Android and macOS devices and Windows devices enrolled without Autopilot are not included, even when they enrolled within the time range.

- **Date of Autopilot profile assignment** counts a device from the day its Autopilot profile was assigned.
- **Date of Intune enrollment** counts a device from the day it enrolled in Intune. An Autopilot device without an Intune object is not listed.

## Attribute to group by

The attribute is a property of the object chosen under **Group by data from**, for example `country` or `department` of the Entra ID user, `manufacturer` of the Intune device or `groupTag` of the Autopilot device. It must not be empty, and `apDevice`, `intuneDevice`, `APAssignmentDate` and `IntuneEnrolledDate` are names the report uses itself. With one of these values the run stops with an error before it reads any data.

## Failed lookups

For every device the runbook reads the Intune device and, depending on the grouping, the Entra ID user or device. A device or user that does not exist counts as not enrolled or leaves the attribute empty. Any other error, such as a missing Graph permission (403 Forbidden) or a service error, is counted: the report is still created, uploaded and shown as Output Data, but it may miss devices or have empty columns, so the run then ends as failed with the number of failed lookups and the first error.

## Configure the storage account for the CSV export

The CSV export uploads the report to an existing Azure Storage account and returns a download link. The runbook creates the container when it is missing, but not the storage account. The managed identity of the Automation Account needs the `Reader and Data Access` role on the storage account.

Configure the storage account in the tenant settings under `RJReport.StorageAccount`, the same settings all report runbooks use (see [Runbook report settings](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)). `LinkExpiryDays` sets how many days the download link stays valid; without it, the link expires after 6 days. `SubscriptionId` is optional, but recommended: it makes sure the upload uses the subscription that contains the storage account (see [Subscription of the Storage Account](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#subscription-of-the-storage-account)).

```json
{
  "Settings": {
    "RJReport": {
      "StorageAccount": {
        "ResourceGroup": "rj-test-runbooks-01",
        "StorageAccountName": "rjrbexports01",
        "SubscriptionId": "00000000-0000-0000-0000-000000000000",
        "LinkExpiryDays": 6
      }
    }
  }
}
```

The runbook-specific settings `EnrolledDevicesReport.ResourceGroup` and `EnrolledDevicesReport.StorageAccount.Name` are still read and take precedence over `RJReport.StorageAccount`. `EnrolledDevicesReport.StorageAccount.Location` and `EnrolledDevicesReport.StorageAccount.Sku` are no longer needed and are ignored. The container name is taken from `EnrolledDevicesReport.Container`; without it, the runbook uses `enrolled-devices-<weeks>w-<date>`.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.ReadWrite.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.Read.All
  - User.Read.All

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the CSV export)


## Parameters
### Weeks
How many weeks back to look for first enrollments.

| Property | Value |
|----------|-------|
| Default Value | 4 |
| Required | false |
| Type | Int32 |

### dataSource
Date of Autopilot profile assignment counts a device from the day its Autopilot profile was assigned, Date of Intune enrollment from the day it enrolled in Intune.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### groupingSource
Where the grouping attribute comes from: no grouping, Entra ID user or device properties, Intune device properties, or Autopilot device properties.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### groupingAttribute
Name of the attribute the devices are grouped by, for example country or department.

| Property | Value |
|----------|-------|
| Default Value | country |
| Required | false |
| Type | String |

### exportCsv
Uploads the report as CSV to the storage account and returns a download link. Needs a configured storage account.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report is uploaded to. Taken from the tenant setting EnrolledDevicesReport.Container, otherwise set per runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting EnrolledDevicesReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

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
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when EnrolledDevicesReport.ResourceGroup is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when EnrolledDevicesReport.StorageAccount.Name is not set.

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

