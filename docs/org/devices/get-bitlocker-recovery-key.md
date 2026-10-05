# Get Bitlocker Recovery Key

Look up a BitLocker recovery key by its key ID

## Detailed description
Finds the BitLocker recovery key that belongs to the key ID shown on a device's recovery screen and returns the key together with the device it belongs to. Use it when a user is locked out at the BitLocker prompt.

## Where to find
Org \ Devices \ Get Bitlocker Recovery Key

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - BitlockerKey.Read.All


## Parameters
### bitlockeryRecoveryKeyId
The key ID displayed on the BitLocker recovery screen of the device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

