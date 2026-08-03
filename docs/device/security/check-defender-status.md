# Check Defender Status

Check a device's presence and risk status in Entra ID and Microsoft Defender for Endpoint

## Detailed description
This runbook compares a device between Entra ID and Microsoft Defender for Endpoint based on its Entra device ID. It reports whether the device exists in each service, returns key properties like onboarding and health state, and evaluates the Defender risk score to flag elevated risk.

## Where to find
Device \ Security \ Check Defender Status

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
- **Type**: WindowsDefenderATP
  - Machine.Read.All


## Parameters
### DeviceId
The Entra device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

