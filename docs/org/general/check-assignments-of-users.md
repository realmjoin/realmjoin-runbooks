# Check Assignments Of Users

Check Intune assignments for one or more user principal names

## Detailed description
This runbook queries Intune policies and optionally app assignments relevant to the specified user(s).
It resolves transitive group membership and reports matching assignments.

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
### UPN
User Principal Names of the users to check assignments for, separated by commas.

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

