# Restrict Or Release Code Execution

Only allow Microsoft-signed code to run on a device, or remove an existing restriction.

## Detailed description
This runbook restricts code execution on a device via Microsoft Defender for Endpoint so that only Microsoft-signed code can run.
Optionally, it can remove an existing restriction.
Provide a short reason so the action is documented in the service.

## Where to find
Device \ Security \ Restrict Or Release Code Execution

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.RestrictExecution


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Release
"Restrict Code Execution" (final value: false) or "Remove Code Restriction" (final value: true) can be selected as action to perform. If set to false, the runbook will restrict code execution on the device in Defender for Endpoint. If set to true, it will remove an existing code execution restriction on the device in Defender for Endpoint.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### Comment
A short reason for the (un)restriction action.

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

