## How the sign-in data is determined

The runbook evaluates the Microsoft Entra **service principal sign-in activity** report
(`/beta/reports/servicePrincipalSignInActivities`). The report holds the date of the last sign-in per
service principal – across delegated and app-only flows, both as client and as resource – and is therefore
not limited to the retention period of the sign-in logs, which keep individual sign-in events for only
7 days (Microsoft Entra ID Free) resp. 30 days (Microsoft Entra ID P1/P2). A threshold of 90 days can
therefore be evaluated as reliably as one of 7 days.

Every enterprise application (service principal) of the tenant is assigned to exactly one of two lists:

- **Inactive applications** – the last sign-in is older than the configured number of days
- **Applications without any sign-in record** – the report contains no sign-in for the application

Requirements:

- A **Microsoft Entra ID P1 or P2** license – the report is part of *Usage & insights* and is not available without it
- The **AuditLog.Read.All** permission for the report and **Directory.Read.All** for the list of service principals

The runbook only reads data. It does not modify the listed applications.

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
