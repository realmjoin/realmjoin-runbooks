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
