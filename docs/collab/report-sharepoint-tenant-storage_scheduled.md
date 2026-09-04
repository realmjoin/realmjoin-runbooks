## How it works

This runbook connects to the SharePoint Online admin center and, on every run, retrieves the tenant's
storage quota and enumerates all SharePoint site collections. OneDrive for Business sites are excluded
from this list, because OneDrive storage does not count against the tenant storage quota being
monitored here. It prints a storage summary and the top site collections by consumed storage to the
runbook output regardless of outcome, then evaluates two independent storage thresholds. An alert email
is sent only when at least one threshold is breached.

### Threshold semantics

- **Low storage** (`AlertLowStorageLimitInMB`) triggers an alert when the tenant's free storage drops
  below the configured value. This is the primary "about to run out of space" warning.
- **Unused storage** (`AlertUnusedStorageLimitInMB`) triggers an alert when the tenant's free storage
  rises above the configured value, which can indicate a large amount of licensed storage that is not
  being used and may be reclaimable. Set this value to `0` to disable the check entirely.
- Both thresholds are evaluated independently and can breach in the same run if
  `AlertLowStorageLimitInMB` is configured higher than `AlertUnusedStorageLimitInMB` — review both
  values together when tuning them for a tenant.
- A healthy run in which neither threshold is breached is not a failure: the storage summary is still
  written to the runbook output, but no email is sent.


## Granting SharePoint access to the managed identity

The tenant-admin PnP cmdlets used by this runbook require an app-only grant that Entra ID cannot assign
through the standard application-permission consent flow used for Microsoft Graph, so it must be done
manually once per tenant:

1. Install the [PnP Management Shell](https://pnp.github.io/powershell/) (or use the Azure Cloud Shell,
   which has it preinstalled).
2. Connect as a Global Administrator and run:
   ```powershell
   Connect-PnPOnline -Url "https://contoso-admin.sharepoint.com" -Interactive
   Grant-PnPAzureADAppSitePermission -AppId "<managed-identity-app-id>" -DisplayName "<automation-account-name>" -Site "https://contoso-admin.sharepoint.com" -Permissions FullControl
   ```
   Replace `<managed-identity-app-id>` with the Automation account's managed identity application ID and
   `<automation-account-name>` with a recognizable label.
3. Allow a few minutes for the grant to propagate before the next scheduled run.

## Interpreting the results

- **Total Quota / Used / Free** summarize the tenant's overall SharePoint Online storage allocation.
- The **top site collections** table lists SharePoint site collections only (OneDrive sites are
  excluded), sorted by consumed storage descending and limited to `TopSiteCount` entries; use it to
  identify which sites are driving tenant storage consumption.
- The alert email, when sent, repeats the storage summary and the top site collections table so the
  recipient does not need to open the runbook job output to act on it.

## Notes and limitations

- `Get-PnPTenantSite` does not reliably report a site's creation date on every tenant or module version;
  affected sites show `Unknown` in the **Created** column instead.
- Enumerating all site collections can take several minutes in tenants with a large number of sites.

## Setup regarding email sending

Sending an alert email is optional and only happens when at least one storage threshold is breached; a recipient (`AlertEmailTo`) is required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Scheduling

A daily schedule is recommended. Since the storage summary is written to the runbook output on every
run — not only when an alert fires — a daily cadence also gives a continuous history of tenant storage
trends in the job output, independent of whether any email was sent.
