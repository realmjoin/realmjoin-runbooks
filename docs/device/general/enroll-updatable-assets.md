# Enroll Updatable Assets

Enroll device into Windows Update for Business.

## Detailed description
This script enrolls devices into Windows Update for Business.

## Where to find
Device \ General \ Enroll Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - WindowsUpdates.ReadWrite.All


## Parameters
### -DeviceId
DeviceId of the device to unenroll.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -UpdateCategory
Category of updates to enroll into. Possible values are: driver, feature or quality.

| Property | Value |
|----------|-------|
| Default Value | feature |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

