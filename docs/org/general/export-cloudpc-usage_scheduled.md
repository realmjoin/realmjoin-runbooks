# Export Cloudpc Usage_Scheduled

## Write daily Windows 365 Utilization Data to Azure Tables

## Description
Write daily Windows 365 Utilization Data to Azure Tables. Will write data about the last full day.

## Where to find
Org \ General \ Export Cloudpc Usage_Scheduled

## Notes
Permissions: 
MS Graph: CloudPC.Read.All
StorageAccount: Contributor

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

