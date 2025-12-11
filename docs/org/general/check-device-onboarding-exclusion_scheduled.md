# Check Device Onboarding Exclusion (Scheduled)

Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

## Detailed description
Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

## Where to find
Org \ General \ Check Device Onboarding Exclusion_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All


## Parameters
### exclusionGroupName
EntraID exclusion group for Defender Compliance.

| Property | Value |
|----------|-------|
| Default Value | cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices) |
| Required | false |
| Type | String |

### maxAgeInDays

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

