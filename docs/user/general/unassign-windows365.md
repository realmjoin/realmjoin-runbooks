# Unassign Windows365

## Remove/Deprovision a Windows 365 instance

## Description
Remove/Deprovision a Windows 365 instance

## Where to find
User \ General \ Unassign Windows365

## Notes
Permissions:
MS Graph (API):
- User.Read.All
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- CloudPC.ReadWrite.All (Beta)

## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -licWin365GroupName
Description: 
Default Value: lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB
Required: false

### -cfgProvisioningGroupPrefix
Description: 
Default Value: cfg - Windows 365 - Provisioning -
Required: false

### -cfgUserSettingsGroupPrefix
Description: 
Default Value: cfg - Windows 365 - User Settings -
Required: false

### -licWin365GroupPrefix
Description: 
Default Value: lic - Windows 365 Enterprise -
Required: false

### -skipGracePeriod
Description: 
Default Value: True
Required: false

### -KeepUserSettingsAndProvisioningGroups
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)

