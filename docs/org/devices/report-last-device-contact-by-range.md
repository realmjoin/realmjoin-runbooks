# Report Last Device Contact By Range

## Reports Windows devices with last device contact within a specified date range.

## Description
This Runbook retrieves a list of Windows devices from Azure AD / Intune, filtered by their
last device contact time (lastSyncDateTime). As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.
The output includes the device name, last sync date, user ID, user display name, and user principal name.

## Where to find
Org \ Devices \ Report Last Device Contact By Range

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All


## Parameters
### -dateRange
Description: Date range for filtering devices based on their last contact time.
Default Value: 
Required: true

### -systemType
Description: The operating system type of the devices to filter.
Default Value: Windows
Required: true


[Back to Table of Content](../../../README.md)

