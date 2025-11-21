# Report Stale Devices (Scheduled)

Scheduled report of stale devices based on last activity date and platform.

## Detailed description
Identifies and lists devices that haven't been active for a specified number of days.
Automatically sends a report via email.

## Where to find
Org \ Devices \ Report Stale Devices_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All
  - Mail.Send


## Parameters
### Days
Number of days without activity to be considered stale.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### Windows
Include Windows devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Include macOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Include iOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Include Android devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

