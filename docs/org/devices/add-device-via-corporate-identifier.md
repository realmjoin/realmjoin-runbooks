# Add Device Via Corporate Identifier

Register a device in Intune by its corporate identifier

## Detailed description
Adds a device to Intune's list of corporate identifiers, such as a serial number or IMEI, so it counts as corporate-owned when it enrolls. An existing entry for the same identifier can be overwritten, and a description can be stored with it.

## Where to find
Org \ Devices \ Add Device Via Corporate Identifier

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### CorpIdentifierType
Serial number for most devices, IMEI for cellular devices.

| Property | Value |
|----------|-------|
| Default Value | serialNumber |
| Required | true |
| Type | String |

### CorpIdentifier
Value of the chosen identifier, exactly as printed on or reported by the device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DeviceDescripton
Free text stored with the identifier, for example the device model or its owner.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverwriteExistingEntry
Replaces an entry that already exists for the same identifier.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

