# Unenroll Updatable Assets

Unenroll device from Windows Update for Business.

## Detailed description
This script unenrolls devices from Windows Update for Business.

## Where to find
Device \ General \ Unenroll Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - WindowsUpdates.ReadWrite.All


## Parameters
### DeviceId
DeviceId of the device to unenroll.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UpdateCategory
Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete).

| Property | Value |
|----------|-------|
| Default Value | all |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

