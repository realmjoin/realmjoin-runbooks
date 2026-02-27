# Check Device Onboarding Exclusion (Scheduled)

Add unenrolled Autopilot devices to an exclusion group

## Detailed description
This runbook identifies Windows Autopilot devices that are not yet enrolled in Intune and ensures they are members of a configured exclusion group.
It also removes devices from the group once they are no longer in scope.

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
Display name of the exclusion group to manage.

| Property | Value |
|----------|-------|
| Default Value | cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices) |
| Required | false |
| Type | String |

### maxAgeInDays
Maximum age in days for recently enrolled devices to be considered in grace scope.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

