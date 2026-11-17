# Sync Device

Trigger an Intune sync on this device

## Detailed description
Asks this device to check in with Intune, so pending policies, apps and configuration are applied without waiting for the next regular check-in. The device name, operating system, primary user and last check-in are shown first. If this device is offline, it syncs when it comes back online. The device must be enrolled in Intune.

## Where to find
Device \ General \ Sync Device

## How it works

The runbook looks up this device in Intune by its Entra ID device ID, shows its current state and sends the same sync request as **Sync** in the Intune admin center. Intune wakes the device through the push service of its platform; the device then checks in, applies pending policies, apps and configuration and reports its state back. An offline device receives the request when it comes back online. The last check-in time in Intune changes only after the check-in has completed.

If an earlier enrollment left more than one Intune record with the same Entra ID device ID, the sync request goes to the record that checked in last and the run shows a warning. Remove the stale records in the Intune admin center.

## Sync without the RealmJoin app permission

The **Sync** button in the [device details](https://docs.realmjoin.com/ugd-management/user-list/device-details) of the RealmJoin Portal asks Intune through the RealmJoin app, which then needs the Intune permission for remote actions on devices. This runbook sends the request with the managed identity of the Automation account instead. Use it when the RealmJoin app does not hold that permission but help desk staff should still be able to sync a device. Who may start the runbook is controlled by the runbook permissions in RealmJoin.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.PrivilegedOperations.All
  - DeviceManagementManagedDevices.Read.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

