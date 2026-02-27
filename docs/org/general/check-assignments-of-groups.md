# Check Assignments Of Groups

Check Intune assignments for one or more group names

## Detailed description
This runbook queries Intune policies and optionally app assignments that target the specified group(s).
It resolves group IDs and reports matching assignments.

## Where to find
Org \ General \ Check Assignments Of Groups

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All
  - Device.Read.All


## Parameters
### GroupIDs
Group IDs of the groups to check assignments for

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |

### IncludeApps
If set to true, also evaluates application assignments.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

