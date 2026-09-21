# Notify Changed CA Policies

Alert by email about Conditional Access policy changes

## Detailed description
Checks which Conditional Access policies were created or changed within the last 24 hours and sends an email with the list attached. Without changes, no email is sent. Nothing is changed in the tenant.

## Where to find
Org \ Security \ Notify Changed CA Policies

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Policy.Read.All
  - Mail.Send
  - User.Read.All


## Parameters
### From
User in the tenant the alert is sent as; needs a mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### To
Gets the email with the list of changed policies.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

