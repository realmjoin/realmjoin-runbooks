# Reset Mobile Device Pin

Reset a mobile device's password/PIN code.

## Detailed description
This runbook triggers an Intune reset passcode action for a managed mobile device.
The action is only supported for certain, corporate-owned device types and will be rejected for personal or unsupported devices.
Optionally, the passcode is only reset when the device's Microsoft Defender for Endpoint risk score is not Medium or High.

## Where to find
Device \ Security \ Reset Mobile Device Pin

## Only reset the passcode if the device is not at risk

When *Only reset passcode if device is not at risk* (`skipIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before the Intune device is looked up and the reset is triggered. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the passcode is reset as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before anything is changed. A device with an elevated risk score may be involved in a security incident; resetting its passcode could grant access to the device or interfere with the investigation. Align with your security team first; to reset the passcode anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the reset. Mobile devices only appear in Defender for Endpoint when the Defender app is deployed and onboarded on them, so devices without Defender are not blocked by the check.
- **Device found, but without a risk score** (e.g. freshly onboarded): the runbook notes this and proceeds as well.
- **Defender query fails**: the runbook stops without resetting the passcode, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every request, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_security_reset-mobile-device-pin": {
    "parameters": {
        "skipIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All
- **Type**: WindowsDefenderATP
  - Machine.Read.All *(optional: Defender risk check)*


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### skipIfAtRisk
If set to true, the passcode is only reset when the device's Microsoft Defender for Endpoint risk score is not Medium or High. This prevents a passcode reset on a device that may be involved in a security incident, which could grant access to the device or interfere with the investigation. Devices that are not found in Defender for Endpoint are not blocked.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

