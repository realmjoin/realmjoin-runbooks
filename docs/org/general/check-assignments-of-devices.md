# Check Assignments Of Devices

## Check Intune assignments for a given (or multiple) Device Names.

## Description
This script checks the Intune assignments for a single or multiple specified Device Names.

## Where to find
Org \ General \ Check Assignments Of Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All


## Parameters
### -DeviceNames
Description: Device Names of the devices to check assignments for, separated by commas.
Default Value: 
Required: true

### -IncludeApps
Description: Boolean to specify whether to include application assignments in the search.
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

