# Outphase Devices

Remove or outphase multiple devices

## Detailed description
This runbook outphases multiple devices based on a comma-separated list of device IDs or serial numbers.
It can optionally wipe devices in Intune and delete or disable the corresponding Entra ID device objects.

## Where to find
Org \ Devices \ Outphase Devices

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
### DeviceListChoice
Determines whether the list contains device IDs or serial numbers.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### DeviceList
Comma-separated list of device IDs or serial numbers.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### intuneAction
Determines whether to wipe the device, delete it from Intune, or skip Intune actions.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### aadAction
Determines whether to delete the Entra ID device, disable it, or skip Entra ID actions.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### wipeDevice
Internal flag derived from intuneAction.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeIntuneDevice
Internal flag derived from intuneAction.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice
"Remove the device from Autopilot" (final value: true) or "Keep device in Autopilot" (final value: false) handles whether to delete the device from the Autopilot database.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeAADDevice
Internal flag derived from aadAction.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### disableAADDevice
Internal flag derived from aadAction.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

