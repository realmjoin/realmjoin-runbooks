# Assign Owa Mailbox Policy

Assign an Outlook on the web policy to this user's mailbox

## Detailed description
Assigns an Outlook on the web (OWA) mailbox policy to the mailbox of this user. Policies switch features on or off, for example email signatures in the web client or the Bookings add-in for people who create Bookings appointments. Get current assignment shows the policy in place without changing it.

## Where to find
User \ Mail \ Assign Owa Mailbox Policy

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### OwaPolicyName
Policy to assign. Get current assignment only shows which policy the mailbox has today.

| Property | Value |
|----------|-------|
| Default Value | OwaMailboxPolicy-Default |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

