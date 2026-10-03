## Configure the storage account for the export

The report files are uploaded to an Azure Storage account. Its subscription, resource group and name come from the tenant settings below; the container name is taken from `OfficeLicensingReport.Container`. The switches of this runbook are backed by `OfficeLicensingReport.*` settings as well, so their defaults can be fixed per tenant.

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
