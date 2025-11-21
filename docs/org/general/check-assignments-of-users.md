# Check Assignments Of Users

Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

## Detailed description
This script checks the Intune assignments for a single or multiple specified UPNs.

## Where to find
Org \ General \ Check Assignments Of Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Device.Read.All


## Parameters
### -UPN
User Principal Names of the users to check assignments for, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -IncludeApps
Boolean to specify whether to include application assignments in the search.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

