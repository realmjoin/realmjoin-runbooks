# Reprovision Windows365

## Reprovision a Windows 365 Cloud PC

## Description
Reprovision an already existing Windows 365 Cloud PC without reassigning a new instance for this user.

## Where to find
User \ General \ Reprovision Windows365

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

### -licWin365GroupName
Description: 
Default Value: lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB
Required: true

### -sendMailWhenReprovisioning
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


[Back to Table of Content](../../../README.md)

