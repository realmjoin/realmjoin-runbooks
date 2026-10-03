# Bulk Retire Devices From Intune

Retire several Intune devices by serial number

## Detailed description
Retires the Intune devices with the given serial numbers. A retire removes company data and management from each device but leaves personal data in place. Serial numbers that are not found are reported and skipped.

## Where to find
Org \ General \ Bulk Retire Devices From Intune

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All


## Parameters
### SerialNumbers
Serial numbers of the devices to retire, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

