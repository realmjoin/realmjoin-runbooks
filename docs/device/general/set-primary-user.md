# Set Primary User

Set a new primary user on this device

## Detailed description
Assigns the chosen user as the new primary user of this device in Intune and replaces the current one. The output shows the previous and the new assignment.

## Where to find
Device \ General \ Set Primary User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - User.Read.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NewPrimaryUserId
User to assign. The current primary user is replaced; both are shown in the output.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

