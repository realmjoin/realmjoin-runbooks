# List Stale Devices_Scheduled

## Scheduled report of stale devices based on last activity date and platform.

## Description
Identifies and lists devices that haven't been active for a specified number of days.
Automatically sends a report via email.

## Where to find
Org \ Devices \ List Stale Devices_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All
  - Mail.Send


## Parameters
### -Days
Description: Number of days without activity to be considered stale.
Default Value: 30
Required: false

### -Windows
Description: Include Windows devices in the results.
Default Value: True
Required: false

### -MacOS
Description: Include macOS devices in the results.
Default Value: True
Required: false

### -iOS
Description: Include iOS devices in the results.
Default Value: True
Required: false

### -Android
Description: Include Android devices in the results.
Default Value: True
Required: false

### -sendAlertTo
Description: Email address to send the report to.
Default Value: support@glueckkanja.com
Required: false

### -sendAlertFrom
Description: Email address to send the report from.
Default Value: runbook@glueckkanja.com
Required: false


[Back to Table of Content](../../../README.md)

