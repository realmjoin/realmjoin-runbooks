# List User Devices

List the devices registered to this group's members

## Detailed description
Lists the devices registered to the users in this group. Optionally the found devices are added to a device group of your choice. Devices are only added to that group, never removed.

## Where to find
Group \ General \ List User Devices

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - Device.Read.All
  - GroupMember.ReadWrite.All *(optional: Move devices to group)*


## Parameters
### GroupID
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### moveGroup
Whether the found devices are added to the chosen device group. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### targetgroup
Group the found devices are added to. Only used when "Action" adds the devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

