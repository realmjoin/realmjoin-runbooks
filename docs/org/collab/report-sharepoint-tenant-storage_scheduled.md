# Report Sharepoint Tenant Storage (Scheduled)

Monitor SharePoint Online tenant storage and alert when thresholds are exceeded

## Detailed description
Scheduled monitor for SharePoint Online tenant storage capacity and usage. Connects to the SharePoint admin center using managed identity, retrieves the tenant storage quota and the top site collections by consumed storage, and reports the full inventory to the runbook output on every run. An alert email is sent only when free storage falls below the configured low-storage limit or unused licensed storage rises above the configured reclaimable threshold.

## Where to find
Org \ Collab \ Report Sharepoint Tenant Storage_Scheduled

## Common use cases

- Scheduled daily health check of the SharePoint Online tenant storage that alerts only when a threshold is breached.
- Spotting a tenant that approaches its storage quota before users are blocked from saving files.
- Spotting a large amount of unused, potentially reclaimable licensed storage.

## Scheduling and output

A daily schedule is recommended. The storage summary and the top site collections are written to the runbook output on every run, regardless of whether a threshold is breached, so the job history stays useful on days without an alert.

## Parameter interactions

- `AlertLowStorageLimitInMB` alerts when the free tenant storage drops below the configured value.
- `AlertUnusedStorageLimitInMB` alerts when the free tenant storage rises above the configured value, an indicator of reclaimable licensed storage. Set it to `0` to disable this check.
- Both checks can fire in the same run only when `AlertLowStorageLimitInMB` is configured higher than `AlertUnusedStorageLimitInMB`; review both values together when tuning the thresholds.
- The alert email is only sent when at least one threshold is breached. A run without a breach completes normally and sends nothing.
- The top site collections list covers SharePoint site collections only. OneDrive for Business sites are excluded because their storage does not count against the tenant storage quota this runbook monitors.

## Limitations

- `Get-PnPTenantSite` does not reliably report the creation date of a site on every tenant or module version; the report shows "Unknown" for such a site.
- Enumerating all site collections can take several minutes in tenants with a large number of sites.


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
### AlertLowStorageLimitInGB

| Property | Value |
|----------|-------|
| Default Value | 200 |
| Required | true |
| Type | Int32 |

### AlertUnusedStorageLimitInGB

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

