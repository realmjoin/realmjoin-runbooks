# Remove Primary User

Remove the primary user from this device

## Detailed description
Clears the primary user of this device in Intune. The device then has no assigned user, which is useful for shared devices or before handing the device to someone else. The user account itself is not changed.

## Where to find
Device \ General \ Remove Primary User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

