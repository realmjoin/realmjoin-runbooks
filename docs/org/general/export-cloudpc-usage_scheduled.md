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
Description: CallerName is tracked purely for auditing purposes
Default Value: CloudPCUsageV2
Required: false

### -ResourceGroupName
Description: 
Default Value: 
Required: true

### -StorageAccountName
Description: 
Default Value: 
Required: true

### -days
Description: 
Default Value: 2
Required: false


[Back to Table of Content](../../../README.md)

