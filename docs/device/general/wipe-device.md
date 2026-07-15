# Wipe Device

Wipe a Windows or MacOS device

## Detailed description
Wipe a Windows or MacOS device. For Windows devices, you can choose between a regular wipe and a protected wipe. For MacOS devices, you can provide a recovery code if needed and specify the obliteration behavior.

## Where to find
Device \ General \ Wipe Device

## Add the device to a compliance exclusion group

When *Add device to compliance exclusion group* (`addToExclusionGroup`) is enabled, the wiped Windows device is added to a compliance exclusion group. Devices in that group receive a longer compliance grace period after they are re-enrolled via Autopilot (this mirrors the **Check Device Onboarding Exclusion** runbook).

By default the group is identified by its **display name** (`exclusionGroupName`). Because display names are not guaranteed to be unique, you can instead pin the group by its **Object ID** (`exclusionGroupId`). When an Object ID is provided, it **always overrides** the display name, so name conflicts can never lead to the wrong group being used. `exclusionGroupId` is hidden by default and is meant to be set via runbook customization.

The group is resolved and validated in an upfront preflight check. If the configured group does not exist, the runbook aborts **before** any wipe/delete/disable action, so no half-applied state is left behind. Adding to the group is skipped for non-Windows devices and when the device is deleted from EntraID (`removeAADDevice`).

### Pin the group by Object ID (recommended)

Preset the group's Object ID and enable the switch, keeping the fields hidden. This avoids any ambiguity from duplicate display names.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupId": {
            "Default": "00000000-0000-0000-0000-000000000000",
            "Hide": true
        },
        "exclusionGroupName": {
            "Hide": true
        }
    }
}
```

Replace `00000000-0000-0000-0000-000000000000` with the Object ID of your group (EntraID > Groups > *your group* > **Object Id**).

### Pin the group by display name

If you prefer to work with the display name (and it is unique in your tenant), preset `exclusionGroupName` and leave `exclusionGroupId` empty so the name is used.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupName": {
            "Default": "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
            "Hide": true
        }
    }
}
```


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - Device.Read.All
  - GroupMember.ReadWrite.All
- **Type**: WindowsDefenderATP
  - Machine.Read.All

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

### wipeDevice
"Wipe this device?" (final value: true) or "Do not wipe device" (final value: false) can be selected as action to perform. If set to true, the runbook will trigger a wipe action for the device in Intune. If set to false, no wipe action will be triggered for the device in Intune.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### useProtectedWipe
Windows-only. If set to true, uses protected wipe.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeIntuneDevice
If set to true, deletes the Intune device object.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice
Windows-only. "Delete device from AutoPilot database?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device from the AutoPilot database, which also allows the device to leave the tenant. If set to false, the device will remain in the AutoPilot database and can be re-assigned to another user/device in the tenant.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAADDevice
"Delete device from EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device object from Entra ID (Azure AD). If set to false, the device object will remain in Entra ID (Azure AD).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### disableAADDevice
"Disable device in EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will disable the device object in Entra ID (Azure AD). If set to false, the device object will remain enabled in Entra ID (Azure AD).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### skipWipeIfAtRisk
If set to true, the wipe is only performed when the device's Microsoft Defender for Endpoint risk score is not Medium or High. This protects forensic data (e.g. logs) of devices that may be involved in a security incident from being destroyed by the wipe.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### addToExclusionGroup
Windows-only. If set to true, the device is added to the compliance exclusion group referenced by 'exclusionGroupName'. This grants the device a longer compliance grace period after it is re-enrolled via Autopilot (see the 'Check Device Onboarding Exclusion' runbook).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### exclusionGroupName
Display name of the compliance exclusion group the device should be added to when 'addToExclusionGroup' is enabled.

| Property | Value |
|----------|-------|
| Default Value | cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices) |
| Required | false |
| Type | String |

### exclusionGroupId
Object ID of the compliance exclusion group. If provided, it always overrides 'exclusionGroupName' (avoids name conflicts). Hidden by default; intended to be set via Runbook Customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### macOsRecoveryCode
MacOS-only. Recovery code for older devices; newer devices may not require this.

| Property | Value |
|----------|-------|
| Default Value | 123456 |
| Required | false |
| Type | String |

### macOsObliterationBehavior
MacOS-only. Controls the OS obliteration behavior during wipe.

| Property | Value |
|----------|-------|
| Default Value | default |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

