# Add Devices Of Users To Group (Scheduled)

Add the devices of a user group's members to a device group

## Detailed description
Adds the devices of all users in a user group to a device group on every run, so device-based policies can follow user membership. Devices already in the group are skipped, and nothing is removed.

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
Name or object ID of the group whose members' devices are collected.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DeviceGroup
Name or object ID of the group the devices are added to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IncludeWindowsDevice
Includes Windows devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeMacOSDevice
Includes macOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeLinuxDevice
Includes Linux devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeAndroidDevice
Includes Android devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeIOSDevice
Includes iOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeIPadOSDevice
Includes iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

