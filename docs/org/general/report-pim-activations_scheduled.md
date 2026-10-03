# Report Pim Activations (Scheduled)

Report the PIM role activations of the last month by email

## Detailed description
Reads the Entra ID audit log for Privileged Identity Management role activations of the last month and sends them as an email report, so privileged access can be reviewed regularly. Nothing is changed.

## Where to find
Org \ General \ Report Pim Activations_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - Mail.Send


## Parameters
### sendAlertTo
Gets the monthly PIM activation report.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom
User in the tenant the report is sent as; needs a mailbox.

| Property | Value |
|----------|-------|
| Default Value | runbook@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

