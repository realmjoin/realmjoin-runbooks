# Outphase Devices

Wipe and clean up several devices at once

## Detailed description
Takes several devices out of service in one go, given as a list of device IDs or serial numbers. You choose whether the devices are wiped or only deleted from Intune, and whether their Autopilot registration is removed. Their Entra ID objects can be deleted, disabled or kept. Optionally the devices are tagged in Microsoft Defender for Endpoint so rules that use the tag can exclude them from automated remediation. A wipe removes all data and cannot be undone.

## Where to find
Org \ Devices \ Outphase Devices

## Microsoft Defender for Endpoint exclusion tag

Microsoft Defender for Endpoint has a native **Exclusion state** (shown in the Device Inventory filter as *Excluded* / *Not Excluded*). This state can only be set through the Defender portal — there is **no API** to set a device's native exclusion state programmatically.

Because the native exclusion state cannot be automated, this runbook instead applies a custom device tag (default `ExcludeFromRemediation`) when *Exclude devices from Defender for Endpoint* is enabled. Each device in the list is looked up by its Entra ID device ID and tagged via `POST /api/machines/{id}/tags`, providing a marker that can be used to filter and target excluded devices.

### One-time setup: make the tag filterable

The portal's **Tags** filter only lists tags that were created through the portal. A tag set purely via the API is attached to the device and visible on the device page, but it does **not** appear in the Tags filter on its own.

To make the exclusion tag visible and usable for filtering in the [Defender Device Inventory](https://security.microsoft.com/machines), one client must be tagged manually once through the portal (select a device > **Manage tags** > "Create new tag", using the exact same tag value). After this one-time step the tag becomes a known, filterable tag, and this runbook can apply it to devices at scale.

> **Note:** This tag is only a label — it does not set the device's native Exclusion state and has no remediation effect on its own. It takes effect only if a Defender device group or automation rule is explicitly configured to match this tag value. Such rules match the tag value directly, independently of the portal **Tags** filter, so the one-time manual step only affects whether the tag is selectable for filtering in the portal UI.

Devices supplied by serial number that are not found in Intune have no Entra ID device ID and are therefore not tagged in Defender.

See [Create and manage device tags](https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags) for details.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - Device.Read.All
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.ReadWrite.All

### RBAC roles
- Cloud Device Administrator


## Parameters
### DeviceListChoice
Whether the list holds Entra ID device IDs or serial numbers.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### DeviceList
Device IDs or serial numbers, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### intuneAction
Completely wipe erases all user and enrollment data on the devices. Delete from Intune only removes the device records, for devices that are already wiped or destroyed. Do not wipe or remove leaves Intune untouched.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### aadAction
Delete removes the device objects from Entra ID, Disable keeps them but blocks sign-ins from the devices, and Keep leaves Entra ID untouched.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### wipeDevice
Legacy switch kept for compatibility. The choice under "Intune action" decides whether the devices are wiped.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeIntuneDevice
Legacy switch kept for compatibility. The choice under "Intune action" decides whether the Intune records are deleted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice
Removing the devices from the Autopilot database lets them leave the tenant and be registered elsewhere. Keeping them allows a later redeployment in this tenant.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeAADDevice
Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are deleted.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### disableAADDevice
Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### excludeFromDefender
Tags the devices in Microsoft Defender for Endpoint with the exclusion tag so rules that use the tag can exclude them from automated remediation. Skip leaves Defender untouched.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### defenderExclusionTag
Tag name written to the devices in Defender for Endpoint, for use in your exclusion rules.

| Property | Value |
|----------|-------|
| Default Value | ExcludeFromRemediation |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

