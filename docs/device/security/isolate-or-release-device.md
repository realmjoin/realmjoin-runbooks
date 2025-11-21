# Isolate Or Release Device

Isolate this device.

## Detailed description
Isolate this device using Defender for Endpoint.

## Where to find
Device \ Security \ Isolate Or Release Device

## Notes
Permissions (WindowsDefenderATP, Application):
- Machine.Read.All
- Machine.Isolate

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.Isolate


## Parameters
### DeviceId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Release

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### IsolationType

| Property | Value |
|----------|-------|
| Default Value | Full |
| Required | false |
| Type | String |

### Comment

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

