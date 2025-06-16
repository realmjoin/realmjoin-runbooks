# Export Policy Report

## Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

## Where to find
Org \ General \ Export Policy Report

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Policy.Read.All

### Permission notes
Azure Storage Account: Contributor role on the Storage Account used for exporting reports


## Parameters
### -produceLinks
Description: 
Default Value: True
Required: false

### -exportJson
Description: 
Default Value: False
Required: false

### -renderLatexPagebreaks
Description: 
Default Value: True
Required: false

### -ContainerName
Description: 
Default Value: rjrb-licensing-report-v2
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

