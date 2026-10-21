# Unenroll Updatable Assets

Unenroll this device from Windows Update for Business

## Detailed description
Removes this device from Windows Update for Business for the chosen update category. Choosing all removes the device as an updatable asset altogether, so Intune no longer manages driver, feature or quality updates for it through the deployment service.

## Where to find
Device \ General \ Unenroll Updatable Assets

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
Update category to unenroll the device from. Choosing all removes the device from Windows Update for Business entirely.

| Property | Value |
|----------|-------|
| Default Value | all |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

