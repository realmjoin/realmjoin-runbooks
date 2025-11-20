# Add Device Via Corporate Identifier

Import a device into Intune via corporate identifier.

## Detailed description
This runbook imports a device into Intune via corporate identifier (serial number or IMEI). It supports overwriting existing entries and adding a description to the device.

## Where to find
Org \ Devices \ Add Device Via Corporate Identifier

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### -CorpIdentifierType
Description: 
Default Value: serialNumber
Required: true

### -CorpIdentifier
Description: 
Default Value: 
Required: true

### -DeviceDescripton
Description: 
Default Value: 
Required: false

### -OverwriteExistingEntry
Description: 
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)

