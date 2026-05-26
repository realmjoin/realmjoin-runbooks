# List MFA Methods

List all MFA / authentication methods of a user

## Detailed description
Retrieves and displays every Microsoft Entra ID authentication method registered for a target user, including phone numbers for phone-based methods. Phone numbers can optionally be masked, showing only the last four digits. Optionally a notification email can be sent to the user informing them that their MFA methods have been retrieved through this runbook.

## Where to find
User \ Security \ List MFA Methods

## Notes
Permissions (managed identity, application):
- UserAuthenticationMethod.Read.All - list authentication methods
- User.Read.All                      - resolve target user
- Organization.Read.All              - read tenant display name for the email body
- Mail.Send                          - only required when NotifyUser is enabled

Privacy / audit:
- This runbook reads sensitive identity data (registered MFA methods, including phone numbers).
  Phone numbers are masked by default. Set MaskPhoneNumbers to false only when full numbers are
  required for legitimate support purposes; the action is logged with CallerName.
- When NotifyUser is enabled, the target user is notified by email that an administrator has
  retrieved their MFA methods. This requires the tenant setting RJReport.EmailSender to be
  configured.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Mail.Send
  - Organization.Read.All
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### UserName
User Principal Name of the target user. Auto-filled by the RealmJoin portal in the user context.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### NotifyUser
When enabled, sends a notification email to the target user informing them that their MFA methods were retrieved by an administrator. Default is disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaskPhoneNumbers
When enabled, all phone numbers are masked except for the last four digits (for example +491234567890 becomes ********7890). Default is disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender email address for the optional notification mail. Sourced from the RealmJoin tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskDisplayName
Service Desk display name for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_DisplayName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskEmail
Service Desk email address for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_EMail.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPhone
Service Desk phone number for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_Phone.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LanguageOverride
Overrides the language used for the notification email. Accepted values are 'DE' (German) or 'EN' (English). If left empty, the language is determined automatically based on the target user's usage location.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

