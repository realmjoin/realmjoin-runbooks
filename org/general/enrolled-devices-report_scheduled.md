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
