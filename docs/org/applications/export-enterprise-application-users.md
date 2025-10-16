# Export Enterprise Application Users

Export a CSV of all (enterprise) application owners and users

## Detailed description
This runbook exports a comprehensive list of all enterprise applications (or all service principals)
in your Azure AD tenant along with their owners and assigned users/groups. Afterwards the CSV file is uploaded
to an Azure Storage Account, from where it can be downloaded.

## Where to find
Org \ Applications \ Export Enterprise Application Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Application.Read.All

### Permission notes
Azure IaaS: - Contributor - access on subscription or resource group used for the export


## Parameters
### -entAppsOnly
Description: 
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

