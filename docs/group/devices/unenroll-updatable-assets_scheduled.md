# Unenroll Updatable Assets (Scheduled)

Unenroll this group's devices from Windows Update for Business

## Detailed description
Removes every device in this group from Windows Update for Business, either for one update category or by deleting the updatable asset registration entirely. Optionally the devices owned by the group's user members are included. Use it to offboard devices from Windows Update for Business reporting or to reset their enrollment.

## Where to find
Group \ Devices \ Unenroll Updatable Assets_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All
  - User.Read.All *(optional: User-owned devices)*


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UpdateCategory
Update category (driver, feature or quality) to unenroll the devices from. Choose all to delete the updatable asset registration entirely.

| Property | Value |
|----------|-------|
| Default Value | all |
| Required | true |
| Type | String |

### IncludeUserOwnedDevices
Also unenrolls every device owned by the users in this group, nested groups included.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

