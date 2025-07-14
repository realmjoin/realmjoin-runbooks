# Unenroll Updatable Assets

## Unenroll devices from Windows Update for Business.

## Description
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
Description: Object ID of the group to unenroll its members.
Default Value: 
Required: true

### -UpdateCategory
Description: Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete).
Default Value: all
Required: true


[Back to Table of Content](../../../README.md)

