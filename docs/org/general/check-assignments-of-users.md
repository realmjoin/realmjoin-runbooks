# Check Assignments Of Users

Show which Intune policies and apps target given users

## Detailed description
Lists the Intune policies, and optionally the apps, that apply to one or more users by resolving their group memberships, nested groups included, and matching them against the assignments. Nothing is changed.

## Where to find
Org \ General \ Check Assignments Of Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementApps.Read.All


## Parameters
### UserPrincipalName
Each picked user is checked separately through their group memberships, nested groups included.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |

### IncludeApps
Also lists the apps assigned to the users.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

