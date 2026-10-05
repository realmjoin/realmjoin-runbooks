# Enable Or Disable Lost Mode

Enable or disable Lost Mode on this supervised iOS or iPadOS device

## Detailed description
Locks this supervised iPhone or iPad with Apple Lost Mode, showing a message and callback number on the lock screen, or lifts Lost Mode once the device is back. Optionally the device is asked for its position after it is locked. Only supervised iOS and iPadOS devices are accepted. The command reaches the device with its next check-in; if it is offline, it is locked as soon as it connects again.

## Where to find
Device \ Security \ Enable Or Disable Lost Mode

## Prerequisites

Lost Mode is an Apple feature for **supervised** iOS and iPadOS devices. A device is supervised when it was enrolled through Apple Business Manager or Apple School Manager (Automated Device Enrollment) or prepared with Apple Configurator. Devices enrolled by the user themselves, personal devices and devices managed by app protection only are not supervised and cannot be locked this way.

Before anything is changed, the runbook checks that the device is enrolled in Intune, runs iOS or iPadOS and is reported as supervised. If one of these checks fails, the run stops with a message that names the reason instead of the raw Intune error.

## What the finder sees

While Lost Mode is active the device is locked and shows the lock screen message, the callback phone number and the footer. The phone number can be called from the lock screen without unlocking the device. Nothing else on the device is usable. The texts are visible to anyone who holds the device, so they should name a contact but no internal details.

At least one of the message and the phone number has to be filled in. A device locked without either gives the finder no way to return it, so the runbook refuses that combination.

Enabling Lost Mode again on a device that is already locked updates the lock screen texts.

## Lifting Lost Mode

Choose *Disable Lost Mode* once the device is back. The device unlocks with its usual passcode after the command has arrived. The request is sent even when Intune already reports Lost Mode as disabled, because the reported state can lag behind the device. If Intune then rejects it because Lost Mode is not active, the run ends without a change.

## Locating the device

With *Locate the device after locking?* set to yes, the runbook asks the device for its position right after Lost Mode was requested. The device answers with its next check-in. The runbook waits for about a minute and shows latitude, longitude, the horizontal accuracy in meters and a map link when the position arrives in time. A device that is offline reports its position later; it is then shown in the Intune admin center on the device's page under **Hardware** and in the device action results.

The location request needs the optional permission listed for the *Locate device* feature. Without it Lost Mode is still enabled and the runbook only warns that the position could not be requested.

## Delays and offline devices

Lost Mode and the location request are device actions that Intune queues. A device that is online receives them within seconds; a device that is switched off or has no network receives them as soon as it connects again. The **Current Lost Mode state** shown at the start of the run and the state in the Intune admin center can lag behind by a few minutes.

## Preset the lock screen texts

To give the helpdesk a tenant-wide default, preset the message and the footer in the runbook customization. The phone number is best left to the person running the runbook, unless one central number is used.

```json
"rjgit-device_security_enable-or-disable-lost-mode": {
    "parameters": {
        "Message": {
            "Default": "This device belongs to Contoso and has been reported lost. Please call the number below to return it."
        },
        "Footer": {
            "Default": "Thank you for your help."
        }
    }
}
```

To always request the position after locking, add `"LocateDevice": { "Default": true, "Hide": true }` to the same block.

## Related runbooks

- **Enable Or Disable Device** (Device/Security) blocks sign-ins with the device in Entra ID. For a lost or stolen device, run it in addition to Lost Mode so tokens on the device cannot be used any more.
- **Reset Mobile Device Pin** (Device/Security) resets the passcode of a corporate iOS device.
- **Wipe Managed App Data** (Device/General) removes company data from devices that are managed by app protection only and cannot be locked with Lost Mode.
- **Wipe Device** (Device/General) is the last resort when the device is not expected to come back.

## Android

Intune also offers a lost mode for Android Enterprise devices that are corporate-owned and fully managed or dedicated. This runbook does not cover Android; the operating system check stops the run for Android devices. Support can be added later without changing the parameters.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementManagedDevices.ReadWrite.All *(optional: Locate device)*


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### LostModeAction
Enable Lost Mode locks the device and shows the lock screen texts. Disable Lost Mode lifts the lock again so the device can be used as usual.

| Property | Value |
|----------|-------|
| Default Value | Enable |
| Required | false |
| Type | String |

### Message
Text shown on the lock screen while the device is locked, for example who the device belongs to. Anyone who finds the device can read it. At least one of "Lock screen message" and "Callback phone number" is needed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PhoneNumber
Phone number shown on the lock screen. The finder can call it from the locked device without unlocking it. Leave empty to show the message only.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Footer
Additional line at the bottom of the lock screen, for example an asset tag or a reward note. Leave empty for no footer.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LocateDevice
Also asks the locked device for its current position and shows the coordinates when they arrive within a minute. A device that is offline answers later; its position is then shown in the Intune admin center.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

