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
