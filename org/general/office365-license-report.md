## Configure the storage account for the export

The report files are uploaded to an existing Azure Storage account; it is not created automatically. The recommended configuration is the shared `RJReport.StorageAccount` setting that the other report runbooks use as well (see [Runbook Report Settings](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)). `LinkExpiryDays` sets how many days the download links stay valid (default 6). `SubscriptionId` is optional, but recommended: it makes sure the upload uses the subscription that contains the storage account (see [Subscription of the Storage Account](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#subscription-of-the-storage-account)). The container name is taken from `OfficeLicensingReport.Container`. The switches of this runbook are backed by `OfficeLicensingReport.*` settings as well, so their defaults can be fixed per tenant.

```json
{
	"Settings": {
		"RJReport": {
			"StorageAccount": {
				"ResourceGroup": "rj-test-runbooks-01",
				"StorageAccountName": "rbexports01",
				"SubscriptionId": "00000000-0000-0000-0000-000000000000",
				"LinkExpiryDays": 6
			}
		}
	}
}
```

The Automation Account's managed identity needs the `Reader and Data Access` role on the storage account.

The runbook-specific settings below are still read. When their resource group and storage account name are set, they take precedence over `RJReport.StorageAccount`; `SubscriptionId` is only used together with them.

```json
{
	"Settings": {
		"OfficeLicensingReport": {
			"ResourceGroup": "rj-test-runbooks-01",
			"SubscriptionId": "00000000-0000-0000-0000-000000000000",
			"StorageAccount": {
				"Name": "rbexports01"
			}
		}
	}
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).
