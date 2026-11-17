## Common use cases

This runbook deletes managed devices from Intune based on inactivity, so use it with care.

- Regular cleanup of stale device records in Intune
- Simulation runs (report-only mode) before enabling the actual deletion
- Scheduled lifecycle management with an audit trail via the email report

## Inactivity threshold

*Days without activity* accepts 1 to 3650 days. A device counts as stale when its last check-in is at least that many days ago.

## User scope filtering

The runbook supports optional group filtering as an additional safety net when deletion is enabled. Members of nested groups count as well.

- **Include group** - only devices whose primary user is a member are in scope. Devices without a primary user, and devices whose primary user was deleted from Entra ID, are left out.
- **Exclude group** - devices whose primary user is a member are skipped, and so are devices whose Entra ID device object is a member of the group itself. A device group such as "Intune - do not delete" therefore protects its devices. Devices of deleted users stay in scope.

Group membership is checked against the primary user's object ID as recorded by Intune, so a changed user principal name does not affect the filter.

A group applies whenever it is set, also when the runbook is started through the API or by a schedule without the *Filter by primary user group?* choice. Choosing *Yes, filter by group membership* without selecting a group stops the run before anything is deleted.

The filter fails closed:

- If a selected group cannot be read, or the include group contains no users, the run stops with an error and no device is deleted.
- If Intune records a primary user for a device but no user object ID, the device is not deleted. It is listed with the status *Skipped: primary user could not be resolved* for manual review.

## Download link

If the upload for the download link fails, the email report and the Output Data are still delivered, so the list of deleted devices is not lost. The job then ends as failed.

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
