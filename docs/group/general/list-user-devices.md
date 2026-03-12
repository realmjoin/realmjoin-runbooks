# List User Devices

List devices owned by group members.

## Detailed description
This runbook enumerates the users in a group and lists their registered devices.
Optionally, it can add the discovered devices to a specified device group.
Use this to create or maintain a device group based on group member ownership.

## Where to find
Group \ General \ List User Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All


## Parameters
### GroupID
Object ID of the group whose members will be evaluated.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### moveGroup
If set to true, the discovered devices are added to the target device group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### targetgroup
Object ID of the target device group that receives the devices when moveGroup is enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

