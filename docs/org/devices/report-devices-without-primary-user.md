# Report Devices Without Primary User

Reports all managed devices in Intune that do not have a primary user assigned.

## Detailed description
This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
The output is a formatted table showing Object ID, Device ID, Display Name, and Last Sync Date/Time for each device without a primary user.

Optionally, the report can be sent via email with a CSV attachment containing detailed device information

## Where to find
Org \ Devices \ Report Devices Without Primary User

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Mail.Send


## Parameters
### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

