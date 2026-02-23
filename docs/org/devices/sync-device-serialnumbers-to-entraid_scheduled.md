# Sync Device Serialnumbers To Entraid (Scheduled)

Sync Intune serial numbers to Entra ID extension attributes

## Detailed description
This runbook retrieves Intune managed devices and syncs their serial numbers into an Entra ID device extension attribute.
It can process all devices or only devices with missing or mismatched values and can optionally send an email report.

## Where to find
Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Device.ReadWrite.All
  - Mail.Send


## Parameters
### ExtensionAttributeNumber
Extension attribute number to update.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### ProcessAllDevices
If set to true, processes all devices; otherwise only devices with missing or mismatched values are processed.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaxDevicesToProcess
Maximum number of devices to process in a single run. Use 0 for unlimited.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### sendReportTo
Email address to send the report to. If empty, no email will be sent.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### sendReportFrom
Email address to send the report from.

| Property | Value |
|----------|-------|
| Default Value | runbook@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

