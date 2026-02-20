# Monitor Pending EPM Requests (Scheduled)

Monitor and report pending Endpoint Privilege Management (EPM) elevation requests.

## Detailed description
Queries Microsoft Intune for pending EPM elevation requests and sends an email report.
Email is only sent when there are pending requests.
Optionally includes detailed information about each request in a table and CSV attachment.

## Where to find
Org \ Security \ Monitor Pending EPM Requests_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Notes
Runbook Type: Scheduled (recommended: hourly or every 1 hours)

Endpoint Privilege Management (EPM) Context:
- EPM allows users to request temporary admin rights for specific applications
- Pending requests require manual review and approval by security admins
- Requests expire automatically if not reviewed within the configured timeframe
- Timely review is critical for user productivity and security posture

Email Behavior:
- Emails are sent individually to each recipient
- No email is sent when there are zero pending requests
- CSV attachment is only included when DetailedReport is enabled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Mail.Send


## Parameters
### DetailedReport
When enabled, includes detailed request information in a table and as CSV attachment.
When disabled, only provides a summary count of pending requests.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

