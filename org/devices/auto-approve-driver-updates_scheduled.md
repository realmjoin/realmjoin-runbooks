## Common use cases

- Test the filters first: use the `WhatIf` parameter to preview which drivers would be approved.
- Auto-approve all drivers: run without any filter parameter.
- Approve specific manufacturers: use `DriverManufacturer` to target vendors such as "Intel" or "AMD".
- Target specific policies: use `PolicyNames` or `PolicyIds` to scope the run to test policies first.
- Monitor the approvals: configure `EmailTo` to receive a detailed report after each run.

## Parameter interactions

- Without a policy filter, all driver update policies are processed.
- Without a driver filter, all pending drivers of the selected policies are approved.
- `PolicyNames` and `PolicyIds` can be combined; both filters apply independently.
- `WhatIf` simulates the approvals without making changes, which is useful for testing the filters.

## Prerequisites

The driver update endpoints are only available on the Microsoft Graph beta API, which this runbook uses.

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
