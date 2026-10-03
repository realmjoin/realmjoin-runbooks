# Rename Devices By Group Tag (Scheduled)

Name Autopilot devices after their group tag and serial number

## Detailed description
Builds the computer name of every Windows Autopilot device from a template of group tag and serial number, for example SITE01-7ABCD12. The name goes into the Autopilot record for the next Autopilot deployment. Enrolled devices whose Intune name differs are renamed through Intune and take the new name after a restart. Hybrid joined and personal devices are only reported. A dry run lists all changes without writing anything.

## Where to find
Org \ Devices \ Rename Devices By Group Tag_Scheduled

## Common use cases

- Replace Autopilot deployment profiles that only exist to give one location its own device name template. One deployment profile without a location prefix is enough: the location comes from the group tag of each Autopilot device, and this runbook writes the resulting name into the Autopilot record before the device is deployed.
- Give devices that were enrolled before the naming scheme existed, or that were registered with a different group tag, the name that matches their current group tag.
- Schedule the runbook daily so that newly registered Autopilot devices carry the right name before their first deployment and group tag changes are picked up automatically.

## Name template and placeholders

The name is built from `NameTemplate`. Two placeholders are replaced, case-insensitive:

| Placeholder | Replaced by |
|---|---|
| `%GROUPTAG%` (or `%ORDERID%`) | the Autopilot group tag of the device |
| `%SERIAL%` | the serial number of the Autopilot record |

Every other character of the template is used as typed, for example `%GROUPTAG%-%SERIAL%` or `PC-%GROUPTAG%%SERIAL%`. Each placeholder must appear exactly once: without the serial number all devices of a location would share one name, and without the group tag there is nothing to derive the location from. A random part is deliberately not supported, because the runbook compares the current name with the expected name on every run and a random part would rename every device on every run.

Group tag and serial number are cleaned before they are inserted: characters other than letters, digits and hyphens are removed, so a group tag `SITE_01` becomes `SITE01` and a serial number `VMware-42 1a 2b` becomes `VMware-421a2b`. Repeated hyphens are collapsed into one, and hyphens at the start or end of a cleaned value or of the shortened serial number are dropped, so the virtual machine serial number `1234-5678-9012-3456-7890-1234-56` with the template `%GROUPTAG%-%SERIAL%` and group tag `SITE01` becomes `SITE01-1234-56` and not `SITE01--1234-56`. The finished name must follow the Windows computer name rules: 15 characters at most, letters, digits and hyphens only, starting and ending with a letter or digit, not digits only. A device whose name would break these rules is reported and skipped.

When the assembled name is longer than 15 characters, only the serial number is shortened; the template text and the group tag stay intact. `SerialTruncation` decides which end of the serial number survives:

| Serial number | `%GROUPTAG%-%SERIAL%` with tag `SITE01` | Keep the end | Keep the start |
|---|---|---|---|
| `7ABCD12` (7 characters) | fits | `SITE01-7ABCD12` | `SITE01-7ABCD12` |
| `5CD1234ABC` (10 characters) | 17 characters, two too many | `SITE01-D1234ABC` | `SITE01-5CD1234A` |
| `012345678901` (12 characters) | 19 characters | `SITE01-45678901` | `SITE01-01234567` |

The `%SERIAL%` macro of an Autopilot deployment profile truncates the serial number from the beginning as well, so the default *Keep the end of the serial number* reproduces the names that devices deployed with such a profile already have. Choose *Keep the start of the serial number* only when an existing naming scheme requires it.

## Which devices are changed and which are skipped

Only Autopilot devices with a group tag are considered; `GroupTagFilter` narrows them further (comma-separated list, exact match, `*` as wildcard, for example `SITE1*` for every location whose tag starts with SITE1). `GroupTagExcludeFilter` removes devices from that scope with the same syntax and is applied after the group tag filter, for example `MTR,SHARED,KIOSK*` to leave meeting room, shared and kiosk devices alone. For each device in scope the runbook compares the expected name with two places:

- The display name of the Autopilot record. It is updated whenever it differs, also for devices that are not enrolled yet and independent of *Rename enrolled devices*. Autopilot uses this name as the computer name at the next deployment of an Entra joined device. For a device that is already running, the field has no effect until the device is reset, so the Autopilot list may show the target name while Intune still shows the old one.
- The device name in Intune, if the device is enrolled. When it differs and *Rename enrolled devices* is on, the runbook queues the Intune rename action. The device picks the new name up at its next check-in and applies it after a restart.

The Output Data tab of the job shows up to four tables: *Summary* with the counters of the run, *Planned changes (dry run)* or *Applied changes* with every device that gets at least one write (the new name and the action per side), *Skipped devices* with every device in scope that was not changed and the governing reason, and *Devices already named* with the devices where nothing was left to do. A table without rows is left out. The action columns use these values:

| Value | Meaning |
|---|---|
| `AlreadyNamed` | The name already matches; nothing to do. |
| `RenameQueued` / `Updated` | The Intune rename was queued / the Autopilot record was updated. In a dry run the values read `WouldRenameQueue` / `WouldUpdate`. |
| `RenamePending` | An Intune rename is still pending or active from an earlier run; it is not queued again. |
| `NotEnrolled` | The device has no Intune record; only the Autopilot record is maintained. |
| `RenameDisabled` | *Rename enrolled devices* is off; the Intune name is left alone. |
| `NotCompanyOwned` | Intune only renames corporate-owned devices. |
| `NotEntraJoined` | Hybrid joined or Entra registered devices cannot be renamed through Intune; hybrid joined devices get their name from the domain join profile. |
| `NameInUseByOtherDevice` | Another Intune device already carries the expected name; renaming would create a duplicate. This usually resolves itself once the other device has been renamed. |
| `RenameFailed` / `UpdateFailed` | The Graph call failed; the error is in the job log. |
| `MaxChangesReached` | *Maximum changes per run* was reached before this device; it is processed in a later run. |

The `Reason` column of the skipped devices names the problem when no valid name could be built: `GroupTagUnusable` or `SerialUnusable` (nothing left after cleaning), `NameTooLong` (template text and group tag alone already fill 15 characters), `NameInvalid` (the finished name breaks the computer name rules, for example digits only) and `NameCollision` (two or more Autopilot records would get the same name, for example placeholder serial numbers such as `Default string` or a collision after truncation). None of these devices is changed. For a device with a valid name the column repeats the action that blocked the change, for example `NotEntraJoined` or `MaxChangesReached`.

## Interplay with Dedup Device Names

**Dedup Device Names (Scheduled)** copies the current Intune name of every device with a unique name into its Autopilot record. When both runbooks are scheduled for Windows devices, the Autopilot display name of a device that this runbook cannot rename (hybrid joined, personal, pending rename, name collision, rename disabled) is written back and forth between the two. Run **Dedup Device Names** with the operating system filter *macOS only* or *Other* once this runbook manages the Windows names, or accept the alternating field for those devices. Devices renamed by this runbook never produce duplicates, because a name collision is detected before anything is written.

## Recommended first run

1. Run with *Dry run* on (the default) and *Group tag filter* set to a single location, for example `SITE01`. Put device types that must keep their names into *Exclude group tags*, for example `MTR,SHARED,KIOSK`. Review the tables in the Output Data tab: the planned changes with their new names, the truncation of long serial numbers and the skipped devices with their reasons.
2. Widen the filter, for example to `SITE1*`, still as a dry run, and check that devices deployed with the previous profile templates show `AlreadyNamed`.
3. Switch *Dry run* off with *Maximum changes per run* set to a manageable number such as 50, so that renames of already enrolled devices arrive in waves. Renamed devices need a restart to complete the rename.
4. Remove the limit and the filter and schedule the runbook, for example daily.

## Behaviour

- The Intune rename action does not restart the device. The new name is applied at the next check-in and becomes effective after the next restart; until then Intune still shows the old name and the runbook reports the rename as pending.
- The Autopilot device name applies to Entra joined deployments only. Hybrid joined devices are named by the domain join profile, and Autopilot device preparation does not use Autopilot device identities at all.
- A rename that failed on the device is queued again on the next run.
- Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All


## Parameters
### NameTemplate
Pattern of the computer name. %GROUPTAG% is replaced by the Autopilot group tag and %SERIAL% by the serial number; other characters stay as typed. Letters, digits and hyphens only, 15 characters at most after replacement.

| Property | Value |
|----------|-------|
| Default Value | %GROUPTAG%-%SERIAL% |
| Required | false |
| Type | String |

### SerialTruncation
Which end of the serial number is kept when the assembled name would exceed 15 characters; only the serial number is shortened. Keeping the end matches what Autopilot itself does with %SERIAL%.

| Property | Value |
|----------|-------|
| Default Value | KeepEnd |
| Required | false |
| Type | String |

### GroupTagFilter
Only devices with one of these Autopilot group tags, separated by commas; SITE1* matches every tag that starts with SITE1. Leave empty for all devices that have a group tag.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupTagExcludeFilter
Devices with one of these Autopilot group tags are left alone, separated by commas; KIOSK* matches every tag that starts with KIOSK. Applied after the group tag filter. Leave empty to exclude nothing.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RenameEnrolledDevices
Also rename devices that are already enrolled in Intune. When off, only the Autopilot record is updated and the name is applied at the next Autopilot deployment.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MaxChangesPerRun
Stops after this many devices have been changed; 0 means no limit. Useful for a staged first run.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### WhatIfMode
Only logs what would change without writing anything.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

