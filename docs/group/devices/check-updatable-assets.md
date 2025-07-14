# Check Updatable Assets

## Check if devices in a group are onboarded to Windows Update for Business.

## Description
This script checks if single or multiple devices (by Group Object ID) are onboarded to Windows Update for Business.

## Where to find
Group \ Devices \ Check Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All

### Permission notes
Azure: Contributor on Storage Account


## Parameters
### -GroupId
Description: Object ID of the group to check onboarding status for its members.
Default Value: 
Required: true


[Back to Table of Content](../../../README.md)

