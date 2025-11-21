# Assign Windows365

Assign/Provision a Windows 365 instance

## Detailed description
Assign/Provision a Windows 365 instance for this user.

## Where to find
User \ General \ Assign Windows365

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - User.SendMail


## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -cfgProvisioningGroupName

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - Win11 |
| Required | false |
| Type | String |

### -cfgUserSettingsGroupName

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - restore allowed |
| Required | false |
| Type | String |

### -licWin365GroupName

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | false |
| Type | String |

### -cfgProvisioningGroupPrefix

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - |
| Required | false |
| Type | String |

### -cfgUserSettingsGroupPrefix

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - |
| Required | false |
| Type | String |

### -sendMailWhenProvisioned

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -customizeMail

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -customMailMessage

| Property | Value |
|----------|-------|
| Default Value | Insert Custom Message here. (Capped at 3000 characters) |
| Required | false |
| Type | String |

### -createTicketOutOfLicenses

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -ticketQueueAddress

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja-gab.com |
| Required | false |
| Type | String |

### -fromMailAddress

| Property | Value |
|----------|-------|
| Default Value | runbooks@contoso.com |
| Required | false |
| Type | String |

### -ticketCustomerId

| Property | Value |
|----------|-------|
| Default Value | Contoso |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

