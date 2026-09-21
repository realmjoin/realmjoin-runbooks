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

Group tag and serial number are cleaned before they are inserted: characters other than letters, digits and hyphens are removed, so a group tag `DE_HAM 01` becomes `DEHAM01` and a serial number `VMware-42 1a 2b` becomes `VMware-421a2b`. The finished name must follow the Windows computer name rules: 15 characters at most, letters, digits and hyphens only, starting and ending with a letter or digit, not digits only. A device whose name would break these rules is reported and skipped.

When the assembled name is longer than 15 characters, only the serial number is shortened; the template text and the group tag stay intact. `SerialTruncation` decides which end of the serial number survives:

| Serial number | `%GROUPTAG%-%SERIAL%` with tag `DEHAM` | Keep the end | Keep the start |
|---|---|---|---|
| `7ABCD12` (7 characters) | fits | `DEHAM-7ABCD12` | `DEHAM-7ABCD12` |
| `5CD1234ABC` (10 characters) | 16 characters, one too many | `DEHAM-CD1234ABC` | `DEHAM-5CD1234AB` |
| `012345678901` (12 characters) | 18 characters | `DEHAM-345678901` | `DEHAM-012345678` |

The `%SERIAL%` macro of an Autopilot deployment profile truncates the serial number from the beginning as well, so the default *Keep the end of the serial number* reproduces the names that devices deployed with such a profile already have. Choose *Keep the start of the serial number* only when an existing naming scheme requires it.

## Which devices are changed and which are skipped

Only Autopilot devices with a group tag are considered; `GroupTagFilter` narrows them further (comma-separated list, exact match, `*` as wildcard, for example `DE*` for all German locations). For each device in scope the runbook compares the expected name with two places:

- The display name of the Autopilot record. It is updated whenever it differs, also for devices that are not enrolled yet and independent of *Rename enrolled devices*. Autopilot uses this name as the computer name at the next deployment of an Entra joined device. For a device that is already running, the field has no effect until the device is reset, so the Autopilot list may show the target name while Intune still shows the old one.
- The device name in Intune, if the device is enrolled. When it differs and *Rename enrolled devices* is on, the runbook queues the Intune rename action. The device picks the new name up at its next check-in and applies it after a restart.

The result table in the Output Data tab lists every device in scope with the action taken for Intune and for Autopilot:

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

The `Reason` column names the problem when no valid name could be built: `GroupTagUnusable` or `SerialUnusable` (nothing left after cleaning), `NameTooLong` (template text and group tag alone already fill 15 characters), `NameInvalid` (the finished name breaks the computer name rules, for example digits only or a hyphen at the end after truncation) and `NameCollision` (two or more Autopilot records would get the same name, for example placeholder serial numbers such as `Default string` or a collision after truncation). None of these devices is changed.

## Interplay with Dedup Device Names

**Dedup Device Names (Scheduled)** copies the current Intune name of every device with a unique name into its Autopilot record. When both runbooks are scheduled for Windows devices, the Autopilot display name of a device that this runbook cannot rename (hybrid joined, personal, pending rename, name collision, rename disabled) is written back and forth between the two. Run **Dedup Device Names** with the operating system filter *macOS only* or *Other* once this runbook manages the Windows names, or accept the alternating field for those devices. Devices renamed by this runbook never produce duplicates, because a name collision is detected before anything is written.

## Recommended first run

1. Run with *Dry run* on (the default) and *Group tag filter* set to a single location, for example `DEHAM`. Review the table in the Output Data tab: the expected names, the truncation of long serial numbers and the skip reasons.
2. Widen the filter, for example to `DE*`, still as a dry run, and check that devices deployed with the previous profile templates show `AlreadyNamed`.
3. Switch *Dry run* off with *Maximum changes per run* set to a manageable number such as 50, so that renames of already enrolled devices arrive in waves. Renamed devices need a restart to complete the rename.
4. Remove the limit and the filter and schedule the runbook, for example daily.

## Behaviour

- The Intune rename action does not restart the device. The new name is applied at the next check-in and becomes effective after the next restart; until then Intune still shows the old name and the runbook reports the rename as pending.
- The Autopilot device name applies to Entra joined deployments only. Hybrid joined devices are named by the domain join profile, and Autopilot device preparation does not use Autopilot device identities at all.
- A rename that failed on the device is queued again on the next run.
- Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.
