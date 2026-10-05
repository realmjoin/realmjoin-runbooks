# Dedup Device Names (Scheduled)

Rename Intune devices that share a display name

## Detailed description
Finds Intune devices that share the same display name and renames the most recently enrolled one of each set. The generated name is a fixed prefix followed by random digits up to the chosen total length. The new name is also written to the matching Windows Autopilot record. An OS filter limits which platforms are checked.

## Where to find
Org \ Devices \ Dedup Device Names_Scheduled

## Common use cases

- Schedule the runbook weekly to resolve duplicate device names that arise from re-enrollment, OS reimaging or cloning workflows automatically.
- The Autopilot sync path is idempotent, so unique devices are normalized in Autopilot as well, also on the first run.

## Parameter interactions

- `NameLength` must be strictly greater than the number of characters in `NamePrefix`. The difference determines how many random digits are appended; for example, `NamePrefix` "CORP" with `NameLength` 8 produces names like "CORP4271".
- The runbook validates this constraint at startup and fails fast when it is violated.

## Behaviour

Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All


## Parameters
### NamePrefix
Fixed start of every generated name, for example PC-.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NameLength
Length of the generated name including the prefix; the rest is filled with random digits, so it must be longer than the prefix.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### OsFilter
Which platforms are checked: all, Windows only, macOS only, or the others (Android, iOS, ChromeOS).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

