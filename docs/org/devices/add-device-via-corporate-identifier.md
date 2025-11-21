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
### CorpIdentifierType

| Property | Value |
|----------|-------|
| Default Value | serialNumber |
| Required | true |
| Type | String |

### CorpIdentifier

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DeviceDescripton

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OverwriteExistingEntry

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

