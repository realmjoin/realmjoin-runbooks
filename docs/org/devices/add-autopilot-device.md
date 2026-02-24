# Add Autopilot Device

Import a Windows device into Windows Autopilot

## Detailed description
This runbook imports a Windows device into Windows Autopilot using the device serial number and hardware hash.
It can optionally wait for the import job to finish and supports tagging during import.

## Where to find
Org \ Devices \ Add Autopilot Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SerialNumber
Device serial number as returned by Get-WindowsAutopilotInfo.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### HardwareIdentifier
Device hardware hash as returned by Get-WindowsAutopilotInfo.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AssignedUser
Optional user to assign to the Autopilot device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Wait
If set to true, the runbook waits until the import job completes.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### GroupTag
Optional group tag to apply to the imported device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

