# Unassign Windows365

Remove and deprovision a Windows 365 Cloud PC for a user

## Detailed description
Removes Windows 365 assignments for a user and deprovisions the associated Cloud PC. Optionally ends the grace period immediately to trigger faster removal.

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
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### licWin365GroupName
Display name of the Windows 365 license group or Frontline provisioning policy to remove.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | false |
| Type | String |

### cfgProvisioningGroupPrefix
Prefix used to detect provisioning-related configuration groups.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - |
| Required | false |
| Type | String |

### cfgUserSettingsGroupPrefix
Prefix used to detect user-settings-related configuration groups.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - |
| Required | false |
| Type | String |

### licWin365GroupPrefix
Prefix used to detect Windows 365 license groups.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - |
| Required | false |
| Type | String |

### skipGracePeriod
If set to true, ends the Cloud PC grace period immediately.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### KeepUserSettingsAndProvisioningGroups
If set to true, does not remove related provisioning and user settings groups.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

