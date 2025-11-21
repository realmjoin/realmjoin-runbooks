# Unenroll Updatable Assets

Unenroll devices from Windows Update for Business.

## Detailed description
This script unenrolls devices from Windows Update for Business.

## Where to find
Group \ Devices \ Unenroll Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All


## Parameters
### -GroupId
Object ID of the group to unenroll its members.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -UpdateCategory
Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete).

| Property | Value |
|----------|-------|
| Default Value | all |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

