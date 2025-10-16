# List Stale Devices_Scheduled

Scheduled report of stale devices based on last activity date and platform.

## Detailed description
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

### -EmailTo
Description: Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.
Default Value: 
Required: true

### -EmailFrom
Description: The sender email address. This needs to be configured in the runbook customization
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

