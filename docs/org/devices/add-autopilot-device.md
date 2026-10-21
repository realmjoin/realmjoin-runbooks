# Add Autopilot Device

Register a Windows device in Windows Autopilot

## Detailed description
Registers a Windows device in Windows Autopilot from its serial number and hardware hash, as collected with Get-WindowsAutopilotInfo. Optionally a group tag is set during the import and the runbook waits until the import has finished.

## Where to find
Org \ Devices \ Add Autopilot Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All
  - User.Read.All *(optional: User assignment)*


## Parameters
### SerialNumber
Serial number of the device as reported by Get-WindowsAutopilotInfo.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### HardwareIdentifier
Hardware hash of the device as reported by Get-WindowsAutopilotInfo.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AssignedUser
User to assign during the import. Microsoft no longer accepts this, so leave it empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Wait
Keeps the runbook running until Autopilot has processed the import, so the result shows in the output.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### GroupTag
Group tag to set on the device, for example to steer it into an Autopilot profile. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

