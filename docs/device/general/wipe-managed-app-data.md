# Wipe Managed App Data

Remove company app data from this MAM-managed device

## Detailed description
Removes company data from apps protected by app protection policies on this device, without wiping the whole device. This is the app selective wipe known from the Intune portal, typically used for lost or stolen devices that are managed by app protection only and not enrolled in Intune. The data is removed the next time each protected app checks in, so the wipe is not instant. Pending requests can be monitored and cancelled in the Intune portal.

## Where to find
Device \ General \ Wipe Managed App Data

## Device matching

MAM app registrations belong to a user, not to a device object. The runbook therefore resolves the
users registered on the device and matches their app registrations against the device's EntraID
device id (`azureADDeviceId`). Registrations without an EntraID device id are matched by the
device's display name as fallback; the runbook output indicates when this fallback was used.

## Wipe behavior

- The company app data is removed the next time each protected app checks in on the device; the
  wipe is not instantaneous.
- Pending wipe requests can be monitored and cancelled in the Intune portal under
  *Apps > App selective wipe*.
- Only app data protected by app protection policies (MAM) is affected. The device object itself
  is not touched: it remains in EntraID (and in Intune/Autopilot, if it is additionally
  MDM-enrolled). To disable or remove the device there as well, run the **Outphase Device**
  runbook (Device \ General) afterwards; for a full wipe of MDM-enrolled devices use
  **Wipe Device**.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementApps.ReadWrite.All
  - Device.Read.All
  - User.Read.All

### RBAC roles
- Intune Administrator


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

