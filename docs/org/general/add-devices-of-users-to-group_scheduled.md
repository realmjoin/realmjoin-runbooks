# Add Devices Of Users To Group (Scheduled)

Sync devices of users in a specific group to another device group.

## Detailed description
This runbook reads accounts from a specified Users group and adds their devices to a specified Devices group. It ensures new devices are also added.

## Where to find
Org \ General \ Add Devices Of Users To Group_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - User.Read.All
  - GroupMember.ReadWrite.All


## Parameters
### -UserGroup
Description: 
Default Value: 
Required: true

### -DeviceGroup
Description: 
Default Value: 
Required: true

### -IncludeWindowsDevice
Description: 
Default Value: False
Required: false

### -IncludeMacOSDevice
Description: 
Default Value: False
Required: false

### -IncludeLinuxDevice
Description: 
Default Value: False
Required: false

### -IncludeAndroidDevice
Description: 
Default Value: False
Required: false

### -IncludeIOSDevice
Description: 
Default Value: False
Required: false

### -IncludeIPadOSDevice
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

