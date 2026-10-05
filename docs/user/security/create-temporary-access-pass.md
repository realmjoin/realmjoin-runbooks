# Create Temporary Access Pass

Create a Temporary Access Pass for this user

## Detailed description
Creates a Temporary Access Pass (TAP) for this user, so they can sign in and set up their authentication methods without a password. Any existing pass is removed first and the new pass is shown in the runbook output. Optionally the user gets an email with the pass, in German for usage location DE and otherwise in English.

## Where to find
User \ Security \ Create Temporary Access Pass

## Activate user notification

This runbook sends an email to the user with the temporary access pass. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_create-temporary-access-pass": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.ReadWrite.All
  - User.Read.All
  - Mail.Send *(optional: Email notification)*


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### LifetimeInMinutes
How long the pass stays valid, between 60 and 480 minutes.

| Property | Value |
|----------|-------|
| Default Value | 240 |
| Required | false |
| Type | Int32 |

### OneTimeUseOnly
A one-time pass works for a single sign-in; otherwise it can be reused until it expires.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### NotifyUser
Whether the user is emailed the new pass. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskDisplayName
Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskEmail
Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPhone
Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskPortalUrl
Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ServiceDeskTicketUrl
Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

