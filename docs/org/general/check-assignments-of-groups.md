# Check Assignments Of Groups

Check Intune assignments for a given (or multiple) Group Names.

## Detailed description
This script checks the Intune assignments for a single or multiple specified Group Names.

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
Boolean to specify whether to include application assignments in the search.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

