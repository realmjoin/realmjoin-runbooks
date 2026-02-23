# Assign Windows365

Assign and provision a Windows 365 Cloud PC for a user

## Detailed description
Assigns the required groups and license or Frontline provisioning policy to initiate Windows 365 provisioning. Optionally notifies the user when provisioning completes and can create a support ticket when licenses are exhausted.

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
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### cfgProvisioningGroupName
Display name of the provisioning policy group or Frontline assignment to use.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - Provisioning - Win11 |
| Required | false |
| Type | String |

### cfgUserSettingsGroupName
Display name of the user settings policy group to use.

| Property | Value |
|----------|-------|
| Default Value | cfg - Windows 365 - User Settings - restore allowed |
| Required | false |
| Type | String |

### licWin365GroupName
Display name of the Windows 365 license group to assign when using dedicated Cloud PCs.

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

### sendMailWhenProvisioned
If set to true, sends an email to the user after provisioning completes.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### customizeMail
If set to true, uses a custom email body.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### customMailMessage
Custom message body used for the notification email.

| Property | Value |
|----------|-------|
| Default Value | Insert Custom Message here. (Capped at 3000 characters) |
| Required | false |
| Type | String |

### createTicketOutOfLicenses
If set to true, creates a service ticket email when no licenses or Frontline seats are available.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ticketQueueAddress
Email address used as ticket queue recipient.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja-gab.com |
| Required | false |
| Type | String |

### fromMailAddress
Mailbox used to send the ticket and user notification emails.

| Property | Value |
|----------|-------|
| Default Value | runbooks@contoso.com |
| Required | false |
| Type | String |

### ticketCustomerId
Customer identifier used in ticket subject lines.

| Property | Value |
|----------|-------|
| Default Value | Contoso |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

