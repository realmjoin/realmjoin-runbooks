# Report Sharepoint Tenant Storage (Scheduled)

Monitor SharePoint Online tenant storage and alert when thresholds are exceeded

## Detailed description
Scheduled monitor for SharePoint Online tenant storage capacity and usage. Connects to the SharePoint admin center using managed identity, retrieves the tenant storage quota and the top site collections by consumed storage, and reports the full inventory to the runbook output on every run. An alert email is sent only when free storage falls below the configured low-storage limit or unused licensed storage rises above the configured reclaimable threshold.

## Where to find
Org \ Collab \ Report Sharepoint Tenant Storage_Scheduled

## Notes
Common Use Cases:
- Scheduled daily health check of SharePoint Online tenant storage, alerting only when a
  threshold is breached.
- Spotting a tenant approaching its storage quota before users are blocked from saving files.
- Spotting a large amount of unused, potentially reclaimable licensed storage.

Runbook Type: Scheduled (recommended: daily). The storage summary and the top site collections
are written to the runbook output on every run regardless of whether a threshold is breached, so
job history remains useful even on days with no alert.

Parameter Interactions:
- AlertLowStorageLimitInMB alerts when free tenant storage drops below the configured value.
- AlertUnusedStorageLimitInMB alerts when free tenant storage rises above the configured value
  (an indicator of reclaimable licensed storage); set it to 0 to disable this check.
- Both checks can fire in the same run only if AlertLowStorageLimitInMB is configured higher than
  AlertUnusedStorageLimitInMB - review both values together when tuning thresholds.
- The alert email is sent only when at least one threshold is breached; a run with no breach
  completes normally and sends nothing.
- The top site collections list covers SharePoint site collections only; OneDrive for Business
  sites are excluded because their storage does not count against the tenant storage quota this
  runbook monitors.


Notes and Limitations:
- Get-PnPTenantSite does not reliably report a site's creation date on every tenant or module
  version; the report shows "Unknown" for that site when this occurs.
- Enumerating all site collections can take several minutes in tenants with a large number of
  sites.

Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Mail.Send
  - Organization.Read.All
- **Type**: Office 365 SharePoint Online
  - Sites.FullControl.All

### Permission notes
SharePoint Online: grant Sites.FullControl.All on the 'Office 365 SharePoint Online' resource (appId 00000003-0000-0ff1-ce00-000000000000) to the Automation Account's managed identity — this app-only grant cannot be made through the standard Entra app-role-assignment flow used for Microsoft Graph and must be assigned manually per tenant.


## Parameters
### AlertLowStorageLimitInMB
Low-storage alert threshold in megabytes. An alert email is sent when free tenant storage falls below this limit.

| Property | Value |
|----------|-------|
| Default Value | 200 |
| Required | true |
| Type | Int32 |

### AlertUnusedStorageLimitInMB
Unused-storage alert threshold in megabytes. An alert email is sent when unused licensed storage (storage assigned but not consumed by any site) rises above this limit, indicating storage that could be reclaimed.

| Property | Value |
|----------|-------|
| Default Value | 1024 |
| Required | false |
| Type | Int32 |

### TopSiteCount
Number of site collections to report, ordered by consumed storage. Default is 10.

| Property | Value |
|----------|-------|
| Default Value | 10 |
| Required | false |
| Type | Int32 |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
URL of a custom header image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
URL of a custom footer image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link target applied to the footer image in report emails, for example the company website. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color used for headings and highlights in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Body text color used in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AlertEmailTo
Recipient email address for alert emails. Emails are sent only when storage thresholds are exceeded.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AlertEmailSubject
Subject line for alert emails.

| Property | Value |
|----------|-------|
| Default Value | RealmJoin - SharePoint Online Storage Alert |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

