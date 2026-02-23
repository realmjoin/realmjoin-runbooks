# Change Grouptag

Assign a new AutoPilot GroupTag to this device.

## Detailed description
This Runbook assigns a new AutoPilot GroupTag to the device. This can be used to trigger a new deployment with different policies and applications for the device.

## Where to find
Device \ General \ Change Grouptag

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### newGroupTag
The new AutoPilot GroupTag to assign to the device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

