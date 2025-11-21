# Enrolled Devices Report (Scheduled)

Show recent first-time device enrollments.

## Detailed description
Show recent first-time device enrollments, grouped by a category/attribute.

## Where to find
Org \ General \ Enrolled Devices Report_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.Read.All
  - DeviceManagementManagedDevices.Read.All
  - User.Read.All
  - Device.ReadWrite.All

### Permission notes
Azure: Contributor on Storage Account


## Parameters
### -Weeks

| Property | Value |
|----------|-------|
| Default Value | 4 |
| Required | false |
| Type | Int32 |

### -dataSource
Where to look for a devices "birthday"?
0 - AutoPilot profile assignment date
1 - Intune object creation date

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### -groupingSource
How to group results?
0 - no grouping
1 - AzureAD User properties
2 - AzureAD Device properties
3 - Intune device properties
4 - AutoPilot properties

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### -groupingAttribute
Examples:

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

| Property | Value |
|----------|-------|
| Default Value | country |
| Required | false |
| Type | String |

### -exportCsv
Please configure an Azure Storage Account to use this feature.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -ContainerName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -ResourceGroupName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -StorageAccountName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -StorageAccountLocation

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -StorageAccountSku

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

