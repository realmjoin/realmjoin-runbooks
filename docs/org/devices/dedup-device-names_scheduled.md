# Dedup Device Names (Scheduled)

Detect and rename duplicate Intune device display names using a prefix and random suffix

## Detailed description
This scheduled runbook queries all Intune managed devices and identifies devices that share the same display name.
For each set of duplicates, the most recently enrolled device is renamed to a generated name consisting of a configurable prefix followed by random digits padded to the specified total length, and that name is persisted in the matching Windows Autopilot device object.
An optional OS filter restricts processing to a specific platform (Windows, macOS, or other); when set to All, devices of every platform are evaluated.

## Where to find
Org \ Devices \ Dedup Device Names_Scheduled

## Notes
Prerequisites:
- The managed identity must have DeviceManagementManagedDevices.ReadWrite.All and DeviceManagementServiceConfig.ReadWrite.All Graph application permissions assigned.
- Autopilot display name changes via updateDeviceProperties take effect at the next device sync and may not reflect immediately in the portal.

Parameter Interactions:
- NameLength must be strictly greater than the character count of NamePrefix. The difference determines how many random digits are appended (e.g., NamePrefix "CORP" with NameLength 8 produces names like "CORP4271").
- The runbook validates this constraint at startup and fails fast if violated.

Common Use Cases:
- Schedule weekly to automatically resolve duplicate device names that arise from re-enrollment, OS reimaging, or cloning workflows.
- The idempotent Autopilot sync path ensures that unique devices are also normalized in Autopilot even on the first run.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### NamePrefix
The fixed prefix used at the start of every generated device name. All renamed devices will begin with this string.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NameLength
The total character length of the generated device name, including the prefix. Must be greater than the length of NamePrefix so there is room for the random digit suffix.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### OsFilter
Restricts which devices are evaluated for duplicate detection and renaming. All includes every platform; Windows and MacOS process only those platforms; Other covers Android, iOS, ChromeOS, and any unrecognized OS. Defaults to All.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

