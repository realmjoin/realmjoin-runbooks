## Interpretation notes

- Checks performed per user: account state, Intune license and service plan, tenant MDM authority, device enrollment limit, platform restrictions, registered authentication methods, Conditional Access policies and, optionally, pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for each user's `EnrollmentPlatform`; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (a documented Entra exemption); only policies targeting device registration or the Intune enrollment apps are treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency and terms of use.
- Expired or already used Temporary Access Passes are not counted as usable methods.

## Prerequisites

At least one of `UserName` or `GroupName` is required; group memberships are resolved transitively.

## Report delivery

Every run writes its results to the Output Data tab of the RealmJoin portal: a summary, the top blocking reasons and one table per readiness status (*Not ready*, *Ready with warnings*, *Ready*). Each table can be exported to Excel there.

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *Output Data only* selected, the results are read directly in the Output Data tab. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

Scheduled runs that were saved with the earlier *Email report* option keep sending their email. When such a schedule is opened for editing, the option shows *Output Data only* although the stored email delivery stays active; select the delivery again before saving so that the dialog matches what the schedule does.

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
