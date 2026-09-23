## Purpose and use cases

- Regular reporting of Endpoint Privilege Management (EPM) activities
- Audit trail for approved and denied elevation requests
- Analysis of expired requests to identify process bottlenecks
- Identification of frequently requested applications for automatic elevation rules

A monthly schedule is recommended.

## Status types

- **Pending:** awaits an admin decision (use **Monitor Pending EPM Requests** for time-critical alerting)
- **Approved:** an admin approved the request, the user can proceed with the elevation
- **Denied:** an admin rejected the request due to security or policy concerns
- **Expired:** the request expired before an admin reviewed it, which may indicate slow response times
- **Revoked:** a previously approved elevation was later revoked by an admin
- **Completed:** the user successfully executed the elevated application after approval

## Data retention and time ranges

- Intune retains EPM request details for 30 days after creation.
- For long-term analysis, archive the CSV exports outside of Intune.
- The default filter covers the states Approved, Denied, Expired and Revoked over the last 30 days.

## Email and export details

- Generates CSV and/or Excel (xlsx) report files with the complete request details (see `ReportFileFormat`).
- Emails are sent individually to each recipient for privacy.
- No email is sent when no request matches the filter criteria.
- The report files include timestamps, users, devices, applications, justifications and file hashes.

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
