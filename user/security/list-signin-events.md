## Required license and permissions

Reading sign-in logs through the Microsoft Graph API requires an **Entra ID P1 or P2 license** in the tenant. Tenants without it receive a 403 error from the sign-in log query even when all Graph permissions are granted. With P1/P2, sign-in logs are retained for up to 30 days; the 7-day retention of the free tier applies to the Entra portal, not to this runbook.

If the sign-in log query returns a 403 although `AuditLog.Read.All` is granted and the tenant is licensed, some tenants additionally require `Directory.Read.All` on the Entra reporting API. Granting it is the known workaround; it is not declared by default because it grants read access to every directory object.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *No report* selected, the sign-in analysis is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.

## Interpreting the results

Entra counts some sign-in interrupts as errors (for example 50140 "Keep me signed in", 50058 and 50076), so they appear as failures and are included in the per-application failure rate. Check the failure reason before treating a high failure rate as a genuine problem. Error codes are Entra ID sign-in error codes; look them up at [https://login.microsoftonline.com/error](https://login.microsoftonline.com/error).

Sign-in log data typically lags ~15 minutes but can take up to 2 hours for some records - a very recent sign-in may not yet appear. All timestamps are shown in UTC.
