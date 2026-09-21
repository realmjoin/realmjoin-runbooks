# Check Device Onboarding Exclusion (Scheduled)

Keep unenrolled Autopilot devices in a compliance exclusion group

## Detailed description
Puts Windows Autopilot devices that are not yet enrolled in Intune, plus devices enrolled only recently, into an exclusion group. Once they are past that grace period, they are taken out again. Devices in the group can get a longer compliance grace period after enrollment.

## Where to find
Org \ General \ Check Device Onboarding Exclusion_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.Read.All


## Parameters
### exclusionGroupName
Display name of the group that holds the excluded devices.

| Property | Value |
|----------|-------|
| Default Value | cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices) |
| Required | false |
| Type | String |

### maxAgeInDays
Devices enrolled within this many days stay in the group; older ones are removed.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

