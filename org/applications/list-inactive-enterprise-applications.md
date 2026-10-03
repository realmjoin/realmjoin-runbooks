## How the sign-in data is determined

The runbook evaluates the Microsoft Entra **service principal sign-in activity** report
(`/beta/reports/servicePrincipalSignInActivities`). The report holds the date of the last sign-in per
service principal - across delegated and app-only flows, both as client and as resource - and is therefore
not limited to the retention period of the sign-in logs, which keep individual sign-in events for only
7 days (Microsoft Entra ID Free) or 30 days (Microsoft Entra ID P1/P2). A threshold of 90 days can
therefore be evaluated as reliably as one of 7 days.

Every enterprise application (service principal) of the tenant is assigned to exactly one of two lists:

- **Inactive applications** - the last sign-in is older than the configured number of days
- **Applications without any sign-in record** - the report contains no sign-in for the application

The report is part of *Usage & insights* in Microsoft Entra ID and needs a **Microsoft Entra ID P1 or P2** license; without it the runbook stops with an error.

The runbook only reads data. It does not modify the listed applications.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *Output Data only* selected, the results are read directly in the Output Data tab of the RealmJoin portal: a summary table plus one table per list (*Inactive applications*, *No sign-in recorded*), each of which can also be exported to Excel. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

When no application is inactive and every application has a recorded sign-in, no file is created. If email delivery is selected, the email is still sent, without attachments, and states that no inactive applications were found.

Schedules that were created before the **Report delivery** option existed keep sending their email: a stored recipient alone still enables the email for them. When such a schedule is opened for editing, the option shows *Output Data only*; select the delivery again before saving, otherwise the schedule stops sending the report.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as **Report delivery**; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).
