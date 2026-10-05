## Configure the storage account for the CSV export

The CSV export uploads the report to an Azure Storage account. Its resource group, name, region and performance tier come from the tenant settings below; the container name is taken from `EnrolledDevicesReport.Container`.

```json
{
  "Settings": {
    "EnrolledDevicesReport": {
      "ResourceGroup": "rj-test-runbooks-01",
      "StorageAccount": {
        "Name": "rjrbexports01",
        "Location": "West Europe",
        "Sku": "Standard_LRS"
      }
    }
  }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).
