# Check Assignments Of Devices

Show which Intune policies and apps target given devices

## Detailed description
Lists the Intune policies, and optionally the apps, that apply to one or more devices by resolving the devices' group memberships and matching them against the assignments. Nothing is changed.

## Where to find
Org \ General \ Check Assignments Of Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementApps.Read.All


## Parameters
### DeviceNames
Names of the devices to check, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IncludeApps
Also lists the apps assigned to the devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

