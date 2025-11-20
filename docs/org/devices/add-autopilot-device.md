# Add Autopilot Device

Import a windows device into Windows Autopilot.

## Detailed description
This runbook imports a windows device into Windows Autopilot using the device's serial number and hardware hash.

## Where to find
Org \ Devices \ Add Autopilot Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### -SerialNumber
Description: 
Default Value: 
Required: true

### -HardwareIdentifier
Description: 
Default Value: 
Required: true

### -AssignedUser
Description: MS removed the ability to assign users directly via Autopilot
Default Value: 
Required: false

### -Wait
Description: 
Default Value: True
Required: false

### -GroupTag
Description: 
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

