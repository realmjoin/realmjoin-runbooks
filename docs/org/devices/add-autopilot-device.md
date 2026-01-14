# Add Autopilot Device

Import a windows device into Windows Autopilot.

## Detailed description
This runbook imports a windows device into Windows Autopilot using the device's serial number and hardware hash.

## Where to find
Org \ Devices \ Add Autopilot Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SerialNumber

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### HardwareIdentifier

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AssignedUser
MS removed the ability to assign users directly via Autopilot

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Wait

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### GroupTag

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

