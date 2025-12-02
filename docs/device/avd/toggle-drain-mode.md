# Toggle Drain Mode

Sets Drainmode on true or false for a specific AVD Session Host.

## Detailed description
This Runbooks looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
The SubscriptionId value must be defined in the runbooks customization.

## Where to find
Device \ AVD \ Toggle Drain Mode

## Permissions
### Permission notes
Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool


## Parameters
### DeviceName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DrainMode

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### SubscriptionIds

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |


[Back to Table of Content](../../../README.md)

