# Report Pim Activations (Scheduled)

Scheduled report on PIM activations

## Detailed description
This runbook queries Microsoft Entra ID audit logs for recent PIM activations.
It builds an report and sends it via email.

## Where to find
Org \ General \ Report Pim Activations_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - Mail.Send


## Parameters
### sendAlertTo
Recipient email address for the report.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom
Sender mailbox UPN used to send the report email.

| Property | Value |
|----------|-------|
| Default Value | runbook@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

