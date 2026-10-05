# Toggle Drain Mode

Enable or disable drain mode on this AVD session host

## Detailed description
Switches drain mode for this Azure Virtual Desktop session host, whichever host pool of the tenant it belongs to. With drain mode on, the host accepts no new sessions, for example before maintenance; existing sessions stay connected. With drain mode off, the host takes new sessions again.

## Where to find
Device \ AVD \ Toggle Drain Mode

## Permissions
### Permission notes
Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool


## Parameters
### DeviceName
Name of the AVD session host. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DrainMode
Whether the host should stop accepting new sessions (drain mode on) or take new sessions again (drain mode off).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### SubscriptionIds
Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |


[Back to Table of Content](../../../README.md)

