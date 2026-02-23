# Enable Or Disable Device

Enable or disable a device in Entra ID

## Detailed description
This runbook enables or disables a Windows device object in Entra ID (Azure AD) based on the provided device ID.
Use it to temporarily block sign-ins from a compromised or lost device, or to re-enable the device after remediation.

## Where to find
Device \ Security \ Enable Or Disable Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All

### RBAC roles
- Cloud device administrator


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Enable
"Disable Device?" (final value: false) or "Enable Device again?" (final value: true) can be selected as action to perform. If set to false, the runbook will disable the device in Entra ID (Azure AD). If set to true, the runbook will enable the device in Entra ID (Azure AD) again.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

