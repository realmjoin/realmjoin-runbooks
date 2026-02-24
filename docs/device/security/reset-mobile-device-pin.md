# Reset Mobile Device Pin

Reset a mobile device's password/PIN code.

## Detailed description
This runbook triggers an Intune reset passcode action for a managed mobile device.
The action is only supported for certain, corporate-owned device types and will be rejected for personal or unsupported devices.

## Where to find
Device \ Security \ Reset Mobile Device Pin

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

