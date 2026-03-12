# Isolate Or Release Device

Isolate this device.

## Detailed description
This runbook isolates a device in Microsoft Defender for Endpoint to reduce the risk of lateral movement and data exfiltration.
Optionally, it can release a previously isolated device.
Provide a short reason so the action is documented in the service.

## Where to find
Device \ Security \ Isolate Or Release Device

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.Isolate


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Release
"Isolate Device" (final value: false) or "Release Device from Isolation" (final value: true) can be selected as action to perform. If set to false, the runbook will isolate the device in Defender for Endpoint. If set to true, it will release a previously isolated device from isolation in Defender for Endpoint.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### IsolationType
The isolation type to use when isolating the device.

| Property | Value |
|----------|-------|
| Default Value | Full |
| Required | false |
| Type | String |

### Comment
A short reason for the (un)isolation action.

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

