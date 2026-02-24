# Get Bitlocker Recovery Key

Get the BitLocker recovery key

## Detailed description
This runbook retrieves a BitLocker recovery key using the recovery key ID from the BitLocker recovery screen.
It returns key details and related device information.

## Where to find
Org \ Devices \ Get Bitlocker Recovery Key

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - BitlockerKey.Read.All


## Parameters
### bitlockeryRecoveryKeyId
Recovery key ID of the desired key.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

