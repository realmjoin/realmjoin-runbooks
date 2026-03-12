# Set Primary User

Set a new primary user on a managed Intune device

## Detailed description
This runbook assigns a new primary user to an Intune managed device. It resolves the Intune managed device from the Entra Object ID provided by the portal, retrieves the current primary user and device details, removes the existing user assignment, and then sets the specified user as the new primary user. The output shows the previous and new assignment for audit purposes.

## Where to find
Device \ General \ Set Primary User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - User.Read.All


## Parameters
### DeviceId
The Entra Object ID of the device. Pre-filled from the RealmJoin Portal and hidden in the UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NewPrimaryUserId
The user to assign as the new primary user of the device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

