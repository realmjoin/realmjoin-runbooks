# Enrolled Devices Report_Scheduled

## Show recent first-time device enrollments.

## Description
Show recent first-time device enrollments, grouped by a category/attribute.

## Where to find
Org \ General \ Enrolled Devices Report_Scheduled

## Notes
Permissions: 
MS Graph (API):
- DeviceManagementServiceConfig.Read.All
- DeviceManagementManagedDevices.Read.All
- User.Read.All
- Device.ReadWrite.All
Azure Subscription (for Storage Account)
- Contributor on Storage Account

## Parameters
### -Weeks
Description: 
Default Value: 4
Required: false

### -dataSource
Description: Where to look for a devices "birthday"?
0 - AutoPilot profile assignment date
1 - Intune object creation date
Default Value: 0
Required: false

### -groupingSource
Description: How to group results?
0 - no grouping
1 - AzureAD User properties
2 - AzureAD Device properties
3 - Intune device properties
4 - AutoPilot properties
Default Value: 1
Required: false

### -groupingAttribute
Description: Examples:

Autopilot:
- "groupTag"
- "systemFamily"
- "skuNumber"

AzureAD User:
- "city"
- "companyName"
- "department"
- "officeLocation"
- "preferredLanguage"
- "state"
- "usageLocation"
- "manager"?

AzureAD Device:
- "manufacturer"
- "model"

Intune Device:
- "isEncrypted"
Default Value: country
Required: false

### -exportCsv
Description: Please configure an Azure Storage Account to use this feature.
Default Value: True
Required: false

### -ContainerName
Description: 
Default Value: 
Required: false

### -ResourceGroupName
Description: 
Default Value: 
Required: false

### -StorageAccountName
Description: 
Default Value: 
Required: false

### -StorageAccountLocation
Description: 
Default Value: 
Required: false

### -StorageAccountSku
Description: 
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

