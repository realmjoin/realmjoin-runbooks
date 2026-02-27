# Assign Owa Mailbox Policy

Assign an OWA mailbox policy to a user

## Detailed description
Assigns an OWA mailbox policy to a mailbox in Exchange Online.
This can be used to enable or restrict features such as the ability to use email signatures in OWA or to enable the Bookings add-in for users who create Bookings appointments.

## Where to find
User \ Mail \ Assign Owa Mailbox Policy

## Permissions
### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the target mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### OwaPolicyName
Name of the OWA mailbox policy to assign.

| Property | Value |
|----------|-------|
| Default Value | OwaMailboxPolicy-Default |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

