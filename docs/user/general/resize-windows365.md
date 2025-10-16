# Resize Windows365

Resize a Windows 365 Cloud PC

## Detailed description
Resize an already existing Windows 365 Cloud PC by derpovisioning and assigning a new differently sized license to the user. Warning: All local data will be lost. Proceed with caution.

## Where to find
User \ General \ Resize Windows365

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - Directory.Read.All
  - CloudPC.ReadWrite.All
  - User.Read.All
  - User.SendMail


## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -currentLicWin365GroupName
Description: 
Default Value: lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB
Required: true

### -newLicWin365GroupName
Description: 
Default Value: lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB
Required: true

### -sendMailWhenDoneResizing
Description: 
Default Value: False
Required: false

### -fromMailAddress
Description: 
Default Value: reports@contoso.com
Required: false

### -customizeMail
Description: 
Default Value: False
Required: false

### -customMailMessage
Description: 
Default Value: Insert Custom Message here. (Capped at 3000 characters)
Required: false

### -cfgProvisioningGroupPrefix
Description: 
Default Value: cfg - Windows 365 - Provisioning -
Required: false

### -cfgUserSettingsGroupPrefix
Description: 
Default Value: cfg - Windows 365 - User Settings -
Required: false

### -unassignRunbook
Description: 
Default Value: rjgit-user_general_unassign-windows365
Required: false

### -assignRunbook
Description: 
Default Value: rjgit-user_general_assign-windows365
Required: false

### -skipGracePeriod
Description: 
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)

