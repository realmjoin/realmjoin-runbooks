## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings).

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Setup regarding RealmJoin API credentials

This runbook queries the RealmJoin customer API and requires a dedicated credential stored in the Azure Automation Account.

**Step-by-step setup:**

1. **Get API credentials** — If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
2. **Open the Automation Account** — In the Azure portal, navigate to the Automation Account used for runbooks
3. **Go to Shared Resources > Credentials** — In the left menu under *Shared Resources*, click *Credentials*
4. **Add a new credential** — Click *Add a credential*
5. **Name it exactly `RJAPI`** — The runbook looks up this name; any deviation will cause the credential lookup to fail
6. **Enter the RealmJoin API username and password** — Use the credentials from step 1
7. **Save** — Click *Create* and re-run the runbook
