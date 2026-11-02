# Office365 License Report

Report Microsoft 365 license usage and availability

## Detailed description
Creates a report of the Microsoft 365 licenses in the tenant, how many are in use and how many are free. Exchange Online details such as shared mailbox licensing can be added. The report files can be uploaded to an Azure Storage account, as single files or as one ZIP, with download links. Nothing is changed unless real user data is requested, which briefly switches off the report privacy setting and restores it afterwards.

## Where to find
Org \ General \ Office365 License Report

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Reports.Read.All
  - ReportSettings.ReadWrite.All
  - User.Read.All
  - AuditLog.Read.All *(optional: Sign-in export)*
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp *(optional: Exchange licensing report)*

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when exportToFile is enabled)

### RBAC roles
- Exchange Administrator *(optional: Exchange licensing report)*


## Parameters
### printOverview
Prints a table per license SKU with total, used, available and suspended counts in the run output.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### includeExchange
Adds Exchange Online reports such as shared mailbox licensing.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### includeUserData
Shows real user names in the activity reports by switching off the report privacy setting for the run; it is restored afterwards. The reports then contain personal data, so check your data protection rules first.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### exportToFile
Uploads the report files to the Azure Storage account configured in the tenant settings.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportAsZip
Uploads one ZIP file instead of the single report files.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### produceLinks
Returns time-limited download links for the uploaded files.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Taken from the tenant setting OfficeLicensingReport.Container.

| Property | Value |
|----------|-------|
| Default Value | rjrb-licensing-report-v2 |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.SubscriptionId and only used with OfficeLicensingReport.*; empty means the subscription the managed identity signs in to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when OfficeLicensingReport.ResourceGroup is not set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RJReportStorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when OfficeLicensingReport.StorageAccount.Name is not set.

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

