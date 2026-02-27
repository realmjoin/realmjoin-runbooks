# Show Laps Password

Show a local admin password for a device.

## Detailed description
This runbook retrieves and displays the most recent Windows LAPS local administrator password that is backed up for the specified device.
Use it for break-glass troubleshooting and rotate the password after use.

## Where to find
Device \ Security \ Show Laps Password

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceLocalCredential.Read.All


## Parameters
### DeviceId
The device ID of the target device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

