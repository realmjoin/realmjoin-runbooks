## Endpoint Privilege Management context

- Endpoint Privilege Management (EPM) allows users to request temporary admin rights for specific applications.
- Pending requests require manual review and approval by security admins.
- Requests expire automatically if they are not reviewed within the configured timeframe.
- A timely review is critical for user productivity and for the security posture.

## Scheduling

An hourly schedule is recommended.

## Email behaviour

- Emails are sent individually to each recipient.
- No email is sent when there are no pending requests.
- Report file attachments (see `ReportFileFormat`) are only included when `DetailedReport` is enabled.

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
