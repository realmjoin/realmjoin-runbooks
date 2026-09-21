# Enable Or Disable Device

Enable or disable this device in Entra ID

## Detailed description
Disables or re-enables the Entra ID object of this device. A disabled device can no longer be used to sign in, which blocks a lost or compromised device; enabling it again lifts the block. Nothing on the device itself is changed.

## Where to find
Device \ Security \ Enable Or Disable Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All

### RBAC roles
- Cloud Device Administrator


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Enable
Disable blocks sign-ins from the device. Enable again lifts an earlier block.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

