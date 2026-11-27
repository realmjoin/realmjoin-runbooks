# Check Updatable Assets

Check Windows Update for Business enrollment of this group's devices

## Detailed description
Checks every device in this group for registration as an updatable asset in Windows Update for Business. The result is written to Output Data as a summary line, then one table with a row per device. Each row shows the enrollment state for the feature, quality and driver update categories and any error Windows Update returns. Nothing is changed on the devices or in the group.

## Where to find
Group \ Devices \ Check Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All

### Permission notes
Azure: Contributor on Storage Account


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

