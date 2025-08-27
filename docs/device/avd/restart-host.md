# Restart Host

## Sets Drainmode on true or false for a specific AVD Session Host.

## Description
This Runbook reboots a specific AVD Session Host. If Users are signed in, they will be disconnected. In any case, Drain Mode will be enabled and the Session Host will be restarted. 
If the SessionHost is not running, it will be started. Once the Session Host is running, Drain Mode is disabled again.

## Where to find
Device \ Avd \ Restart Host

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

