# Sync Apple Tokens

Sync Apple Enrollment Program Tokens and VPP Tokens with Intune

## Detailed description
This runbook triggers synchronization of Apple tokens in Microsoft Intune. It can sync Apple Enrollment Program (ADE) tokens, Volume Purchase Program (VPP) tokens, or both. The sync ensures that Intune has the latest information from Apple Business Manager regarding device enrollments and app licenses.

## Where to find
Org \ General \ Sync Apple Tokens

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementApps.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SyncType
Select which token type(s) to synchronize with Apple Business Manager.

| Property | Value |
|----------|-------|
| Default Value | Both |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

