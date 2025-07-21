# Sync Device Serialnumbers To Entraid_Scheduled

## Syncs serial numbers from Intune devices to Azure AD device extension attributes.

## Description
This runbook retrieves all managed devices from Intune, extracts their serial numbers,
and updates the corresponding Azure AD device objects' extension attributes.
This helps maintain consistency between Intune and Azure AD device records.

## Where to find
Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled

## Notes
Permissions (Graph):
- DeviceManagementManagedDevices.Read.All
- Directory.ReadWrite.All
- Device.ReadWrite.All

## Parameters
### -ExtensionAttributeNumber
Description: 
Default Value: 1
Required: false

### -ProcessAllDevices
Description: If true, processes all devices. If false, only processes devices with missing or mismatched serial numbers in AAD.
Default Value: False
Required: false

### -MaxDevicesToProcess
Description: Maximum number of devices to process in a single run. Use 0 for unlimited.
Default Value: 0
Required: false

### -sendReportTo
Description: Email address to send the report to. If empty, no email will be sent.
Default Value: 
Required: false

### -sendReportFrom
Description: Email address to send the report from.
Default Value: runbook@glueckkanja.com
Required: false


[Back to Table of Content](../../../README.md)

