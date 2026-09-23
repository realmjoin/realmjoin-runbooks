# Reset Mobile Device Pin

Reset the passcode of this mobile device

## Detailed description
Triggers an Intune passcode reset for this mobile device. Intune supports this only for certain corporate-owned device types and rejects it for personal or unsupported devices. Optionally the reset is skipped when Microsoft Defender for Endpoint rates the device as medium or high risk.

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
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### skipIfAtRisk
Skips the reset when Microsoft Defender for Endpoint rates the device as medium or high risk, so a reset cannot open a device that is under investigation. Devices unknown to Defender are not blocked.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

