# Bulk Delete Devices From Autopilot

Delete several Autopilot registrations by serial number

## Detailed description
Removes the Windows Autopilot registrations of the devices with the given serial numbers, for example before a device is handed to another tenant or disposed of. Serial numbers that are not found are reported and skipped.

## Where to find
Org \ General \ Bulk Delete Devices From Autopilot

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SerialNumbers
Serial numbers of the devices to remove, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

