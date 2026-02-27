# Delete Stale Devices (Scheduled)

Scheduled deletion of stale devices based on last activity

## Detailed description
This runbook identifies Intune managed devices that have not been active for a defined number of days.
It can optionally delete the matching devices and can send an email report.

## Where to find
Org \ Devices \ Delete Stale Devices_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - Directory.Read.All
  - Device.Read.All
  - Mail.Send


## Parameters
### Days
Number of days without activity to be considered stale

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### Windows
Include Windows devices in the results

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Include macOS devices in the results

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Include iOS devices in the results

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Include Android devices in the results

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DeleteDevices
If set to true, the script will delete the stale devices. If false, it will only report them.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ConfirmDeletion
If set to true, the script will prompt for confirmation before deleting devices.
Should be set to false for scheduled runs.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### sendAlertTo
Email address to send the report to.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom
Email address to send the report from.

| Property | Value |
|----------|-------|
| Default Value | runbook@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

