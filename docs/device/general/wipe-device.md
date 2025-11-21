# Wipe Device

Wipe a Windows or MacOS device

## Detailed description
Wipe a Windows or MacOS device.

## Where to find
Device \ General \ Wipe Device

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - Device.Read.All

### RBAC roles
- Cloud device administrator


## Parameters
### DeviceId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### wipeDevice

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### useProtectedWipe

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeIntuneDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAADDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### disableAADDevice

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### macOsRecevoryCode
Only for old MacOS devices. Newer devices can be wiped without a recovery code.

| Property | Value |
|----------|-------|
| Default Value | 123456 |
| Required | false |
| Type | String |

### macOsObliterationBehavior
"default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails.

| Property | Value |
|----------|-------|
| Default Value | default |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

