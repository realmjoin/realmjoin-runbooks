# Bulk Retire Devices From Intune

Bulk retire devices from Intune using serial numbers

## Detailed description
Retires multiple Intune devices based on a comma-separated list of serial numbers. Each serial number is looked up in Intune and the device is retired if found.

## Where to find
Org \ General \ Bulk Retire Devices From Intune

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - Device.Read.All


## Parameters
### SerialNumbers
Comma-separated list of device serial numbers to retire.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

