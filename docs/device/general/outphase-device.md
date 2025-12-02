# Outphase Device

Remove/Outphase a windows device

## Detailed description
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
### DeviceId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### intuneAction

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### aadAction

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### wipeDevice

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeIntuneDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeAADDevice

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### disableAADDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

