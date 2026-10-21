# Resize Windows365

Resize the Windows 365 Cloud PC of this user

## Detailed description
Moves the Windows 365 Cloud PC of this user to a different size by removing the current license assignment and provisioning a new Cloud PC with the new license. The old Cloud PC is deprovisioned, so data stored only on it is lost; ask the user to back up first. Optionally the user gets an email when the new Cloud PC is ready.

## Where to find
User \ General \ Resize Windows365

## Offer the license groups as dropdowns

Both license fields are text fields by default. Offer the license groups of your tenant as dropdowns via runbook customization (the same list for the current and the new license):

```json
"rjgit-user_general_resize-windows365": {
    "Parameters": {
        "currentLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        },
        "newLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The resize runs the *Unassign Windows 365* and *Assign Windows 365* runbooks in sequence; their Azure Automation names are preset in the hidden parameters `unassignRunbook` and `assignRunbook`.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - Directory.Read.All
  - CloudPC.ReadWrite.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### currentLicWin365GroupName
License group the user is removed from; the Cloud PC behind it is deprovisioned.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | true |
| Type | String |

### newLicWin365GroupName
License group that provides the new size. Must differ from the current one.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB |
| Required | true |
| Type | String |

### sendMailWhenDoneResizing
Sends the user an email once the new Cloud PC is ready.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### fromMailAddress
Mailbox the notification email is sent from.

| Property | Value |
|----------|-------|
| Default Value | reports@contoso.com |
| Required | false |
| Type | String |

### customizeMail
Replaces the standard notification text with your own message.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### customMailMessage
Text of the notification email.

| Property | Value |
|----------|-------|
| Default Value | Insert Custom Message here. (Capped at 3000 characters) |
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

### unassignRunbook
Name of the runbook that removes the current assignment. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | rjgit-user_general_unassign-windows365 |
| Required | false |
| Type | String |

### assignRunbook
Name of the runbook that assigns the new size. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | rjgit-user_general_assign-windows365 |
| Required | false |
| Type | String |

### skipGracePeriod
Deletes the old Cloud PC right away instead of after the 7-day grace period.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

