# Add Devices Of Users To Group (Scheduled)

Sync devices of users in a specific group to another device group

## Detailed description
This runbook reads accounts from a specified users group and adds their devices to a specified device group.
It can filter devices by operating system and keeps the target group in sync.

## Where to find
Org \ General \ Add Devices Of Users To Group_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - User.Read.All
  - GroupMember.ReadWrite.All


## Parameters
### UserGroup
Name or object ID of the users group, to which the target users belong.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DeviceGroup
Name or object ID of the device group, to which the devices should be added.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IncludeWindowsDevice
If set to true, includes Windows devices in the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeMacOSDevice
If set to true, includes macOS devices in the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeLinuxDevice
If set to true, includes Linux devices in the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeAndroidDevice
If set to true, includes Android devices in the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeIOSDevice
If set to true, includes iOS devices in the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeIPadOSDevice
If set to true, includes iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

