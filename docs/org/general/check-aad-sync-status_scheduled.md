# Check Aad Sync Status (Scheduled)

Check last Azure AD Connect sync status

## Detailed description
This runbook checks whether on-premises directory synchronization is enabled and when the last sync happened.
It can send an email alert if synchronization is not enabled.

## Where to find
Org \ General \ Check Aad Sync Status_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All


## Parameters
### sendAlertTo
Email address to send the report to.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom
Sender mailbox used for sending the report.

| Property | Value |
|----------|-------|
| Default Value | runbooks@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

