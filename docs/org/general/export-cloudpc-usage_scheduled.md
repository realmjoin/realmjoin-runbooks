# Export Cloudpc Usage (Scheduled)

Write daily Windows 365 utilization data to Azure Table Storage

## Detailed description
Collects Windows 365 Cloud PC remote connection usage for the last full day and writes it to an Azure Table. The runbook creates the table if needed and merges records per tenant and timestamp.

## Where to find
Org \ General \ Export Cloudpc Usage_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - CloudPC.Read.All

### Permission notes
Azure IaaS: `Contributor` role on the Azure Storage Account used for storing CloudPC usage data


## Parameters
### Table
Name of the Azure Table Storage table to write to.

| Property | Value |
|----------|-------|
| Default Value | CloudPCUsageV2 |
| Required | false |
| Type | String |

### ResourceGroupName
Name of the Azure Resource Group containing the Storage Account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### StorageAccountName
Name of the Azure Storage Account hosting the table.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Days
Number of days to look back when collecting usage data.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

