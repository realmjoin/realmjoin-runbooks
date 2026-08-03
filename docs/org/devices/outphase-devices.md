# Outphase Devices

Remove or outphase multiple devices

## Detailed description
This runbook outphases multiple devices based on a comma-separated list of device IDs or serial numbers.
It can optionally wipe devices in Intune and delete or disable the corresponding Entra ID device objects.
Optionally, each device can be tagged in Microsoft Defender for Endpoint to mark it as excluded from remediation.
NOTE: The Exclusion Tag is applied to the device, but it only appears in the Defender portal's "Tags" filter once it has been created once via the portal (Device > Manage tags > "Create new tag").

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
- Cloud device administrator


## Parameters
### DeviceListChoice
Determines whether the list contains device IDs or serial numbers.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### DeviceList
Comma-separated list of device IDs or serial numbers.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### intuneAction
Determines whether to wipe the device, delete it from Intune, or skip Intune actions.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### aadAction
Determines whether to delete the Entra ID device, disable it, or skip Entra ID actions.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### wipeDevice
Internal flag derived from intuneAction.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeIntuneDevice
Internal flag derived from intuneAction.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### removeAutopilotDevice
"Remove the device from Autopilot" (final value: true) or "Keep device in Autopilot" (final value: false) handles whether to delete the device from the Autopilot database.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### removeAADDevice
Internal flag derived from aadAction.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### disableAADDevice
Internal flag derived from aadAction.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### excludeFromDefender
If set to true, each device will be tagged in Microsoft Defender for Endpoint with the specified exclusion tag. If set to false, the Defender step will be skipped entirely.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### defenderExclusionTag
The tag that will be added to the device in Microsoft Defender for Endpoint to mark it as excluded. Defaults to "ExcludeFromRemediation".

| Property | Value |
|----------|-------|
| Default Value | ExcludeFromRemediation |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

