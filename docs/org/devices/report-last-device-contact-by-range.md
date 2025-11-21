# Report Last Device Contact By Range

Reports devices with last contact within a specified date range.

## Detailed description
This Runbook retrieves a list of devices from Intune, filtered by their last device contact time (lastSyncDateTime).
As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.

The output includes the device name, last sync date, Intune device ID, and user principal name.

Optionally, the report can be sent via email with a CSV attachment containing additional details (Entra ID Device ID, User ID).

## Where to find
Org \ Devices \ Report Last Device Contact By Range

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Mail.Send


## Parameters
### -dateRange
Date range for filtering devices based on their last contact time.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -systemType
The operating system type of the devices to filter.

| Property | Value |
|----------|-------|
| Default Value | Windows |
| Required | true |
| Type | String |

### -EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

