# User Signout

Sign this user out of their AVD sessions

## Detailed description
Finds the Azure Virtual Desktop sessions of this user, active or disconnected, in all host pools of the configured subscriptions and signs the user out of them. Unsaved work in those sessions is lost.

## Where to find
User \ AVD \ User Signout

## Permissions
### Permission notes
Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### SubscriptionIds
Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |


[Back to Table of Content](../../../README.md)

