# Check Defender Status

Check this device in Entra ID and Defender for Endpoint

## Detailed description
Looks up this device in Entra ID and in Microsoft Defender for Endpoint. It shows whether the device exists in each, its onboarding and health state in Defender, and its Defender risk score. A medium or high risk score is flagged. Nothing is changed.

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
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

