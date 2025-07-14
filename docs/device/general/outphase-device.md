# Outphase Device

## Remove/Outphase a windows device

## Description
Remove/Outphase a windows device. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

## Where to find
Device \ General \ Outphase Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - Device.Read.All

### RBAC roles
- Cloud device administrator


## Parameters
### -DeviceId
Description: 
Default Value: 
Required: true

### -intuneAction
Description: 
Default Value: 2
Required: false

### -aadAction
Description: 
Default Value: 2
Required: false

### -wipeDevice
Description: 
Default Value: True
Required: false

### -removeIntuneDevice
Description: 
Default Value: False
Required: false

### -removeAutopilotDevice
Description: 
Default Value: True
Required: false

### -removeAADDevice
Description: 
Default Value: True
Required: false

### -disableAADDevice
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

