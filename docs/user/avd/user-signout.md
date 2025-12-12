# User Signout

Removes (Signs Out) a specific User from their AVD Session.

## Detailed description
This Runbooks looks for active User Sessions in all AVD Hostpools of a tenant and removes forces a Sign-Out of the user.
The SubscriptionIds value must be defined in the runbooks customization.

## Where to find
User \ AVD \ User Signout

## Permissions
### Permission notes
Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool


## Parameters
### UserName
The username (UPN) of the user to sign out from their AVD session. Hidden in UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### SubscriptionIds
Array of Azure subscription IDs where the AVD resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |


[Back to Table of Content](../../../README.md)

