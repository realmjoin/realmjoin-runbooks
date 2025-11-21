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
### UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### currentLicWin365GroupName

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | true |
| Type | String |

### newLicWin365GroupName

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB |
| Required | true |
| Type | String |

### sendMailWhenDoneResizing

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### fromMailAddress

| Property | Value |
|----------|-------|
| Default Value | reports@contoso.com |
| Required | false |
| Type | String |

### customizeMail

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### customMailMessage

| Property | Value |
|----------|-------|
| Default Value | Insert Custom Message here. (Capped at 3000 characters) |
| Required | false |
| Type | String |

### cfgProvisioningGroupPrefix

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - |
| Required | false |
| Type | String |

### cfgUserSettingsGroupPrefix

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - |
| Required | false |
| Type | String |

### unassignRunbook

| Property | Value |
|----------|-------|
| Default Value | rjgit-user_general_unassign-windows365 |
| Required | false |
| Type | String |

### assignRunbook

| Property | Value |
|----------|-------|
| Default Value | rjgit-user_general_assign-windows365 |
| Required | false |
| Type | String |

### skipGracePeriod

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

