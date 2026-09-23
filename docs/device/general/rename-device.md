# Rename Device

Rename this device in Intune and Autopilot

## Detailed description
Gives this device a new name in Intune and in its Windows Autopilot record. Before anything is changed, the name is checked against the Windows computer name rules. It may have up to 15 letters, digits and hyphens, must start and end with a letter or digit, and cannot be digits only.

## Where to find
Device \ General \ Rename Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NewDeviceName
Up to 15 letters, digits and hyphens, starting and ending with a letter or digit, not digits only.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

