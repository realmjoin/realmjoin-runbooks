# Assign Windows365

Provision a Windows 365 Cloud PC for this user

## Detailed description
Assigns this user the groups that trigger Windows 365 provisioning: the provisioning policy or Frontline assignment, the user settings policy and, for a dedicated Cloud PC, the license group. Optionally the user gets an email once the Cloud PC is ready, and a service ticket is opened by email when no licenses or Frontline seats are left.

## Where to find
User \ General \ Assign Windows365

## Offer the policy and license groups as dropdowns

The provisioning policy, user settings policy and license group are plain text fields by default. Turn them into dropdowns with the group names of your tenant via runbook customization:

```json
"rjgit-user_general_assign-windows365": {
    "Parameters": {
        "cfgProvisioningGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - Provisioning - Win11": "cfg - Windows 365 - Provisioning - Win11",
                "cfg - Windows 365 - Provisioning - Win10": "cfg - Windows 365 - Provisioning - Win10"
            }
        },
        "cfgUserSettingsGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - User Settings - restore allowed": "cfg - Windows 365 - User Settings - restore allowed",
                "cfg - Windows 365 - User Settings - no restore": "cfg - Windows 365 - User Settings - no restore"
            }
        },
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The group name prefixes (`cfgProvisioningGroupPrefix`, `cfgUserSettingsGroupPrefix`) decide which groups count as provisioning or user settings groups; adjust them in the same place when your naming differs.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - GroupMember.ReadWrite.All
  - Group.ReadWrite.All
  - Mail.Send *(optional: Email report)*
  - CloudPC.Read.All
  - Organization.Read.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### cfgProvisioningGroupName
Provisioning policy group for a dedicated Cloud PC, or the name of the Frontline provisioning policy. Type the name, or pick it when your runbook customization offers a list.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - Win11 |
| Required | false |
| Type | String |

### cfgUserSettingsGroupName
Group that carries the user settings policy, for example whether the user may restore the Cloud PC.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - restore allowed |
| Required | false |
| Type | String |

### licWin365GroupName
License group for a dedicated Cloud PC. Not needed for Frontline.

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

### sendMailWhenProvisioned
Sends the user an email as soon as provisioning has finished.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### customizeMail
Replaces the standard notification text with your own message. Only used when the user is notified.

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

### createTicketOutOfLicenses
Sends a ticket email to the service desk when no license or Frontline seat is available.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ticketQueueAddress
Mailbox of the service desk that turns the email into a ticket.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja-gab.com |
| Required | false |
| Type | String |

### fromMailAddress
Mailbox the notification and ticket emails are sent from.

| Property | Value |
|----------|-------|
| Default Value | runbooks@contoso.com |
| Required | false |
| Type | String |

### ticketCustomerId
Customer identifier put into the ticket subject.

| Property | Value |
|----------|-------|
| Default Value | Contoso |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

