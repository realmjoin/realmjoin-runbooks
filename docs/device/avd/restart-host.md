# Restart Host

Restart this AVD session host and return it to service

## Detailed description
Restarts this Azure Virtual Desktop session host. Signed-in users are disconnected. Drain mode is switched on first so no new sessions land on the host. A stopped host is started instead of rebooted. Once the host runs again, drain mode is switched off.

## Where to find
Device \ AVD \ Restart Host

## Permissions
### Permission notes
Azure: Desktop Virtualization Host Pool Contributor and Virtual Machine Contributor on Subscription which contains the Hostpool


## Parameters
### DeviceName
Name of the AVD session host. Set by the portal from the selected device.

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

