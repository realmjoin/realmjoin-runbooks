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

## Output and report files

- The Output Data tab of the run shows a *Summary* table with the counts and one table per selected status (for example *Approved requests*), oldest request first.
- The report files hold every matching request with all details: timestamps, users, devices, applications, justifications and file hashes. They are generated as CSV and/or Excel (xlsx), depending on the selected report file format.
- Emails are sent individually to each recipient for privacy.
- No email is sent and no file is created when no request matches the filter criteria. Such a run completes normally; the Output Data tab still shows the summary.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *Output Data only* selected, the results are read directly in the Output Data tab of the RealmJoin portal, where each table can also be exported to Excel. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

Schedules that were created before the **Report delivery** option existed keep sending their email: a stored recipient alone still enables the email for them. When such a schedule is opened for editing, the option shows *Output Data only*; select the delivery again before saving, otherwise the schedule stops sending the report.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).
