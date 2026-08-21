## Setup regarding email sending

Sending an email report is optional and only happens when the `SendMail` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.
