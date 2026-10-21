# Restrict Or Release Code Execution

Restrict this device to Microsoft-signed code or lift the restriction

## Detailed description
Restricts this device through Microsoft Defender for Endpoint so that only Microsoft-signed code can run, which blocks unsigned tools an attacker may have placed on it. It can also lift an existing restriction. Give a short reason; it is recorded with the action in Defender.

## Where to find
Device \ Security \ Restrict Or Release Code Execution

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.RestrictExecution


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Release
Restrict allows only Microsoft-signed code to run on the device. Remove lifts an existing restriction.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### Comment
Short reason for the restriction or its removal. It is stored with the action in Defender for Endpoint.

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

