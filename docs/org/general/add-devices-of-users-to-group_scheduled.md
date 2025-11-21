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

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -DeviceGroup

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -IncludeWindowsDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -IncludeMacOSDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -IncludeLinuxDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -IncludeAndroidDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -IncludeIOSDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -IncludeIPadOSDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

