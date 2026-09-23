# Check Aad Sync Status (Scheduled)

Check the last Entra Connect sync and alert when it is off

## Detailed description
Checks whether directory synchronization from on-premises Active Directory is enabled in the tenant. If it is not, an alert email is sent.

## Where to find
Org \ General \ Check Aad Sync Status_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Mail.Send


## Parameters
### sendAlertTo
Gets the alert email when directory synchronization is found disabled.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom
User in the tenant the alert is sent as; needs a mailbox.

| Property | Value |
|----------|-------|
| Default Value | runbooks@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

