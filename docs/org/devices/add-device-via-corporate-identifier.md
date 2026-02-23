# Add Device Via Corporate Identifier

Import a device into Intune via corporate identifier

## Detailed description
This runbook imports a device into Intune using a corporate identifier such as serial number or IMEI.
It can overwrite existing entries and optionally stores a description for the imported identity.

## Where to find
Org \ Devices \ Add Device Via Corporate Identifier

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.ReadWrite.All


## Parameters
### CorpIdentifierType
Identifier type to use for import.

| Property | Value |
|----------|-------|
| Default Value | serialNumber |
| Required | true |
| Type | String |

### CorpIdentifier
Identifier value to import.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DeviceDescripton
Optional description stored for the imported identity.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverwriteExistingEntry
If set to true, an existing entry for the same identifier will be overwritten.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

