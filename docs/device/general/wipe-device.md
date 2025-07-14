# Wipe Device

## Wipe a Windows or MacOS device

## Description
Wipe a Windows or MacOS device.

## Where to find
Device \ General \ Wipe Device

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

### -wipeDevice
Description: 
Default Value: True
Required: false

### -useProtectedWipe
Description: 
Default Value: False
Required: false

### -removeIntuneDevice
Description: 
Default Value: False
Required: false

### -removeAutopilotDevice
Description: 
Default Value: False
Required: false

### -removeAADDevice
Description: 
Default Value: False
Required: false

### -disableAADDevice
Description: 
Default Value: False
Required: false

### -macOsRecevoryCode
Description: Only for old MacOS devices. Newer devices can be wiped without a recovery code.
Default Value: 123456
Required: false

### -macOsObliterationBehavior
Description: "default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails.
Default Value: default
Required: false


[Back to Table of Content](../../../README.md)

