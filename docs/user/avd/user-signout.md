# User Signout

Removes (Signs Out) a specific User from their AVD Session.

## Detailed description
This Runbooks looks for active User Sessions in all AVD Hostpools of a tenant and removes forces a Sign-Out of the user.
The SubscriptionIds value must be defined in the runbooks customization.

## Where to find
User \ AVD \ User Signout

## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -SubscriptionIds

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |


[Back to Table of Content](../../../README.md)

