# Assign Windows365

## Assign/Provision a Windows 365 instance

## Description
Assign/Provision a Windows 365 instance for this user.

## Where to find
User \ General \ Assign Windows365

## Notes
Permissions:
MS Graph (API):
- User.Read.All
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- User.SendMail

## Parameters
### -UserName
Description: 
Default Value: 
Required: true

### -cfgProvisioningGroupName
Description: 
Default Value: cfg - Windows 365 - Provisioning - Win11
Required: false

### -cfgUserSettingsGroupName
Description: 
Default Value: cfg - Windows 365 - User Settings - restore allowed
Required: false

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

### -sendMailWhenProvisioned
Description: 
Default Value: False
Required: false

### -customizeMail
Description: 
Default Value: False
Required: false

### -customMailMessage
Description: 
Default Value: Insert Custom Message here. (Capped at 3000 characters)
Required: false

### -createTicketOutOfLicenses
Description: 
Default Value: False
Required: false

### -ticketQueueAddress
Description: 
Default Value: support@glueckkanja-gab.com
Required: false

### -fromMailAddress
Description: 
Default Value: runbooks@contoso.com
Required: false

### -ticketCustomerId
Description: 
Default Value: Contoso
Required: false


[Back to Table of Content](../../../README.md)

