## How owners and assignments are shown

Each row is one owner (`PrincipalRole` `Owner`) or one assignment (`PrincipalRole` `Member`) of an application. An application without an owner gets one owner row with an empty `PrincipalId`.

- Owners can be users or service principals, told apart by `PrincipalType`. A user is shown with its user principal name, a service principal with its display name and its application ID in brackets.
- Assigned users are shown with their user principal name, assigned groups with their mail nickname and display name, assigned service principals with their object ID.
- When a lookup fails, for example because of a missing permission, `PrincipalId` shows `(lookup failed)`, after the object ID where it is known, and the run writes a warning. Such a row does not mean that the application has no owner or assignment.

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
