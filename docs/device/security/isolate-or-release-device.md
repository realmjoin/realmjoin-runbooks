# Isolate Or Release Device

Isolate this device from the network or release it

## Detailed description
Isolates this device in Microsoft Defender for Endpoint so that, with full isolation, it can only talk to the Defender service. That limits lateral movement and data theft during an incident. It can also release a previously isolated device. Give a short reason; it is recorded with the action in Defender.

## Where to find
Device \ Security \ Isolate Or Release Device

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.Isolate


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Release
Isolate cuts the device off from the network, with full isolation except for the Defender service. Release restores its normal connectivity.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### IsolationType
Full blocks all traffic except to Defender; Selective keeps Outlook, Teams and Skype for Business working. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | Full |
| Required | false |
| Type | String |

### Comment
Short reason for the isolation or release. It is stored with the action in Defender for Endpoint.

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

