# Change Grouptag

Assign a new Autopilot group tag to this device

## Detailed description
Sets a new Windows Autopilot group tag on this device. The group tag decides which Autopilot profile and, through dynamic groups, which policies and apps the device gets, so changing it prepares the device for a different deployment. Nothing else on the device is changed.

## Where to find
Device \ General \ Change Grouptag

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### newGroupTag
Group tag that decides which Autopilot profile and dynamic groups the device gets.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

