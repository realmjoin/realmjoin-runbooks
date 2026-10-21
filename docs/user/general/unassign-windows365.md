# Unassign Windows365

Remove the Windows 365 Cloud PC of this user

## Detailed description
Removes the Windows 365 license or Frontline assignment of this user and, unless another Cloud PC remains, the provisioning and user settings groups, which deprovisions the Cloud PC. Data stored only on the Cloud PC is lost. Optionally the grace period is skipped so the Cloud PC is deleted right away.

## Where to find
User \ General \ Unassign Windows365

## Offer the license groups as a dropdown

The license field is a text field by default. Offer the license groups (or Frontline provisioning policy groups) of your tenant as a dropdown via runbook customization:

```json
"rjgit-user_general_unassign-windows365": {
    "Parameters": {
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The group name prefixes (`cfgProvisioningGroupPrefix`, `cfgUserSettingsGroupPrefix`, `licWin365GroupPrefix`) decide which of the user's groups count as Windows 365 groups; adjust them in the same place when your naming differs.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - CloudPC.ReadWrite.All
  - Organization.Read.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### licWin365GroupName
License group to remove the user from, or the name of the Frontline provisioning policy whose assignment is removed.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | false |
| Type | String |

### cfgProvisioningGroupPrefix
Name prefix that identifies provisioning policy groups. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - |
| Required | false |
| Type | String |

### cfgUserSettingsGroupPrefix
Name prefix that identifies user settings policy groups. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - |
| Required | false |
| Type | String |

### licWin365GroupPrefix
Name prefix that identifies Windows 365 license groups. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - |
| Required | false |
| Type | String |

### skipGracePeriod
Deletes the Cloud PC right away instead of after the 7-day grace period.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### KeepUserSettingsAndProvisioningGroups
Leaves the user in the provisioning and user settings groups and removes only the license.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

