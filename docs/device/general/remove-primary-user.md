# Remove Primary User

Removes the primary user from a device.

## Detailed description
This script removes the assigned primary user from a specified Azure AD device.
It requires the DeviceId of the target device and the name of the caller for auditing purposes.

## Where to find
Device \ General \ Remove Primary User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All


## Parameters
### -DeviceId
The unique identifier of the device from which the primary user will be removed.
It will be prefilled from the RealmJoin Portal and is hidden in the UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

