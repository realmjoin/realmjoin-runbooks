# Unassign Windows365

Remove/Deprovision a Windows 365 instance

## Detailed description
Remove/Deprovision a Windows 365 instance

## Where to find
User \ General \ Unassign Windows365

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - CloudPC.ReadWrite.All


## Parameters
### UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### licWin365GroupName

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
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

### licWin365GroupPrefix

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - |
| Required | false |
| Type | String |

### skipGracePeriod

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### KeepUserSettingsAndProvisioningGroups

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

