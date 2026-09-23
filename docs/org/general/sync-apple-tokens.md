# Sync Apple Tokens

Sync Apple enrollment and VPP tokens with Intune

## Detailed description
Triggers a sync of the Apple tokens in Intune, so device enrollments from Apple Business Manager and app licenses from the Volume Purchase Program are up to date. Either token type or both can be synced.

## Where to find
Org \ General \ Sync Apple Tokens

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementApps.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SyncType
Sync the Enrollment Program tokens, the VPP tokens, or both.

| Property | Value |
|----------|-------|
| Default Value | Both |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

