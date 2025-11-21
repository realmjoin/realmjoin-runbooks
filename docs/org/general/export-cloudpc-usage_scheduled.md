# Export Cloudpc Usage (Scheduled)

Write daily Windows 365 Utilization Data to Azure Tables

## Detailed description
Write daily Windows 365 Utilization Data to Azure Tables. Will write data about the last full day.

## Where to find
Org \ General \ Export Cloudpc Usage_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - CloudPC.Read.All

### Permission notes
Azure IaaS: `Contributor` role on the Azure Storage Account used for storing CloudPC usage data


## Parameters
### -Table
CallerName is tracked purely for auditing purposes

| Property | Value |
|----------|-------|
| Default Value | CloudPCUsageV2 |
| Required | false |
| Type | String |

### -ResourceGroupName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -StorageAccountName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -days

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

