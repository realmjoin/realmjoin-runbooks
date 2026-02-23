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
  - Device.Read.All


## Parameters
### GroupNames
Group Names of the groups to check assignments for, separated by commas.

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

