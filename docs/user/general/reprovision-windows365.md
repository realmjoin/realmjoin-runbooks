# Reprovision Windows365

Reprovision a Windows 365 Cloud PC

## Detailed description
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

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -licWin365GroupName

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | true |
| Type | String |

### -sendMailWhenReprovisioning

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -fromMailAddress

| Property | Value |
|----------|-------|
| Default Value | reports@contoso.com |
| Required | false |
| Type | String |

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


[Back to Table of Content](../../../README.md)

