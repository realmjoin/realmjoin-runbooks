# Notify Changed CA Policies

Send notification email if Conditional Access policies have been created or modified in the last 24 hours.

## Detailed description
Checks Conditional Access policies for changes in the last 24 hours and sends an email with a text attachment listing the changed policies. If no changes are detected, no email is sent.

## Where to find
Org \ Security \ Notify Changed CA Policies

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Policy.Read.All
  - Mail.Send


## Parameters
### From
Sender email address used to send the notification.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### To
Recipient email address for the notification.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

