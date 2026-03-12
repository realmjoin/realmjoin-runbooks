# Check Autopilot Serialnumbers

Check if given serial numbers are present in Autopilot

## Detailed description
This runbook checks whether Windows Autopilot device identities exist for the provided serial numbers.
It returns the serial numbers found and lists any missing serial numbers.

## Where to find
Org \ General \ Check Autopilot Serialnumbers

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.Read.All


## Parameters
### SerialNumbers
Serial numbers of the devices, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

