# Restart Host

Reboots a specific AVD Session Host.

## Detailed description
This Runbook reboots a specific AVD Session Host. If Users are signed in, they will be disconnected. In any case, Drain Mode will be enabled and the Session Host will be restarted.
If the SessionHost is not running, it will be started. Once the Session Host is running, Drain Mode is disabled again.

## Where to find
Device \ AVD \ Restart Host

## Parameters
### -DeviceName
Description: 
Default Value: 
Required: true

### -SubscriptionIds
Description: 
Default Value: 
Required: true


[Back to Table of Content](../../../README.md)

