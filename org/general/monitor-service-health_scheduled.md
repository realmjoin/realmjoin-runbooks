## Common use cases

- Schedule the runbook to run at or slightly more often than `LookbackHours` to catch every new Service Health issue exactly once.
- Set `Services` to a comma-separated list of service names or short ids (matched case-insensitively) to monitor only specific services, such as Exchange Online or Teams; leave it empty to monitor all services.
- Leave `IncludeAdvisories` and `IncludeResolvedIssues` at their default of `false` for the lowest-noise setup, which alerts only on unresolved incidents; set either to `true` to also surface advisories or issues Microsoft has already marked as resolved.

## Parameter interactions

- An issue counts as newly announced when its first Service Health post falls inside the `LookbackHours` window (falling back to `startDateTime` if the issue has no posts), not by `lastModifiedDateTime` alone. This avoids missing back-dated issues while preventing re-alerts on every status update of an ongoing incident.
- The runbook keeps no state between runs, so a failed or skipped run means those alerts are never sent unless `LookbackHours` is temporarily widened for a catch-up run.
- One email is sent per new issue, so a busy Service Health day can produce several emails per run.

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
