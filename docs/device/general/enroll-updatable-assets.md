# Enroll Updatable Assets

Enroll this device in Windows Update for Business

## Detailed description
Registers this device as an updatable asset in Windows Update for Business for the chosen update category, so Intune can manage driver, feature or quality updates for it. All enrolls it in driver, feature and quality updates.

## Where to find
Device \ General \ Enroll Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - WindowsUpdates.ReadWrite.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UpdateCategory
Update category to enroll the device in. All enrolls it in driver, feature and quality updates.

| Property | Value |
|----------|-------|
| Default Value | Feature |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

