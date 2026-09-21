# Reprovision Windows365

Reprovision the Windows 365 Cloud PC of this user

## Detailed description
Reprovisions the existing Windows 365 Cloud PC of this user. The Cloud PC is rebuilt from scratch with the same license, so everything stored on it is lost; the user keeps the assignment. Optionally the user gets an email when the reprovisioning starts.

## Where to find
User \ General \ Reprovision Windows365

## Offer the license groups as a dropdown

The license group is a text field by default. Offer the license groups of your tenant as a dropdown via runbook customization:

```json
"rjgit-user_general_reprovision-windows365": {
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

### licWin365GroupName
License group of the Cloud PC to reprovision. Type the group name, or pick it when your runbook customization offers a list.

| Property | Value |
|----------|-------|
| Default Value | lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB |
| Required | true |
| Type | String |

### sendMailWhenReprovisioning
Sends the user an email as soon as the reprovisioning has begun.

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


[Back to Table of Content](../../../README.md)

