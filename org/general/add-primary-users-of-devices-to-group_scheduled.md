## Common use cases

- Keeping a distribution or Conditional Access target group aligned with "who currently has a managed device", filtered by platform, by an advanced OData filter or by an include/exclude group scope.
- Validating a new or changed filter or scope before it is allowed to write to a production group.

A daily schedule is recommended.

## Report-only mode for pilots and testing

Enable `ReportOnly` to compute the same add/remove diff a real run would produce, without applying any change to the group. Instead, a Markdown preview email listing the affected users by UPN is sent to `EmailTo`: each list (would be added, would be removed) shows at most 10 users in the mail body, with a "... and N more" pointer when a list is longer, and the complete lists are attached as report file(s) in the format chosen by `ReportFileFormat`. Run once in this mode after changing the platform selection, `AdvancedFilter` or the include/exclude groups, review the preview, then disable `ReportOnly` to let the sync apply.

## Parameter interactions

- `AdvancedFilter`, when set, replaces the Windows/macOS/iOS/Android platform selection entirely rather than combining with it.
- `RemoveUsersWhenNoDeviceMatch` controls both the real run and the `ReportOnly` preview: when disabled, no users are removed in either case, so the preview always reflects what a real run would do.

## Setup regarding email sending

Sending an email report is optional and only happens when the `ReportOnly` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).
