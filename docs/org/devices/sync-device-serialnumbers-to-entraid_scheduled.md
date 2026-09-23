# Sync Device Serialnumbers To Entraid (Scheduled)

Copy Intune serial numbers into an Entra ID extension attribute

## Detailed description
Writes the serial number of each Intune managed device into one of the extension attributes of its Entra ID device object. That makes the serial number usable in dynamic groups and filters. By default only devices with a missing or different value are updated. A report can be sent by email.

## Where to find
Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
  - Device.ReadWrite.All
  - DeviceManagementManagedDevices.Read.All
  - Mail.Send *(optional: Email report)*


## Parameters
### ExtensionAttributeNumber
Which of the Entra ID extension attributes (1 to 15) receives the serial number.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### ProcessAllDevices
Writes the attribute on every device, not only where it is missing or differs.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaxDevicesToProcess
Stops after this many devices; 0 means no limit.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### sendReportTo
Address the report is sent to. Leave empty to send none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### sendReportFrom
Sender address of the report email. Use a mailbox that exists in the tenant.

| Property | Value |
|----------|-------|
| Default Value | runbook@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

