# Check Assignments Of Groups

Show which Intune policies and apps target given groups

## Detailed description
Lists the Intune policies, and optionally the apps, that are assigned to one or more groups. Nothing is changed.

## Where to find
Org \ General \ Check Assignments Of Groups

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementApps.Read.All


## Parameters
### GroupIDs
Assignments are matched against each picked group directly; assignments to parent groups are not included.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |

### IncludeApps
Also lists the apps assigned to the groups.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

