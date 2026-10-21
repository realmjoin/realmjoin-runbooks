# Office365 License Report

Report Microsoft 365 license usage and availability

## Detailed description
Creates a report of the Microsoft 365 licenses in the tenant, how many are in use and how many are free. Exchange Online details such as shared mailbox licensing can be added. The report files can be uploaded to an Azure Storage account, as single files or as one ZIP, with download links. Nothing is changed unless real user data is requested, which briefly switches off the report privacy setting and restores it afterwards.

## Where to find
Org \ General \ Office365 License Report

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Reports.Read.All
  - Directory.Read.All
  - User.Read.All
  - ReportSettings.ReadWrite.All
  - AuditLog.Read.All *(optional: Sign-in export)*
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp *(optional: Exchange licensing report)*

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
Resource group of the storage account. Taken from the tenant setting OfficeLicensingReport.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for the export. Taken from the tenant setting OfficeLicensingReport.StorageAccount.Name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Azure subscription that holds the storage account. Taken from the tenant setting OfficeLicensingReport.SubscriptionId.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

