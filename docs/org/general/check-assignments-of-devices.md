# Check Assignments Of Devices

Check Intune assignments for one or more device names

## Detailed description
This runbook queries Intune policies and optionally app assignments relevant to the specified device(s).
It resolves device group memberships and reports matching assignments.

## Where to find
Org \ General \ Check Assignments Of Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All


## Parameters
### DeviceNames
Comma-separated list of device names to check.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IncludeApps
If set to true, also evaluates application assignments.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

