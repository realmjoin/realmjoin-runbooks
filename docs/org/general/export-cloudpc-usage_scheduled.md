# Export Cloudpc Usage (Scheduled)

Write daily Windows 365 usage data to an Azure table

## Detailed description
Collects how the Windows 365 Cloud PCs were used, based on the remote connection reports of the chosen number of past days. The figures are written to an Azure Table so they can be tracked over time. The table is created when missing, and records for the same day are updated rather than duplicated.

## Where to find
Org \ General \ Export Cloudpc Usage_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - CloudPC.Read.All
  - Organization.Read.All

### Permission notes
Azure IaaS: `Contributor` role on the Azure Storage Account used for storing CloudPC usage data


## Parameters
### Table
Table in the storage account the usage data is written to. Created when it does not exist yet.

| Property | Value |
|----------|-------|
| Default Value | CloudPCUsageV2 |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that holds the storage account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### StorageAccountName
Storage account that holds the table.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Days
Usage of the past this many days is collected; days already in the table are updated, not added again.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

