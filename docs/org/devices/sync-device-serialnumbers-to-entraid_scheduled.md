# Sync Device Serialnumbers To Entraid (Scheduled)

Syncs serial numbers from Intune devices to Azure AD device extension attributes.

## Detailed description
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

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.ReadWrite.All
  - Device.ReadWrite.All


## Parameters
### ExtensionAttributeNumber

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### ProcessAllDevices
If true, processes all devices. If false, only processes devices with missing or mismatched serial numbers in AAD.

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

