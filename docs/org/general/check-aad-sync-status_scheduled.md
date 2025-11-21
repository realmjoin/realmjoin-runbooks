# Check Aad Sync Status (Scheduled)

Check for last Azure AD Connect Sync Cycle.

## Detailed description
This runbook checks the Azure AD Connect sync status and the last sync date and time.

## Where to find
Org \ General \ Check Aad Sync Status_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All


## Parameters
### sendAlertTo

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja.com |
| Required | false |
| Type | String |

### sendAlertFrom

| Property | Value |
|----------|-------|
| Default Value | runbooks@glueckkanja.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

