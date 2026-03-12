# Bulk Delete Devices From Autopilot

Bulk delete Autopilot objects by serial number

## Detailed description
This runbook deletes Windows Autopilot device identities based on a comma-separated list of serial numbers.
It searches for each serial number and deletes the matching Autopilot object if found.

## Where to find
Org \ General \ Bulk Delete Devices From Autopilot

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### SerialNumbers
Comma-separated list of serial numbers to delete from Autopilot.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

