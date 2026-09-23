# Report Sharepoint Tenant Storage (Scheduled)

Monitor SharePoint storage and alert when limits are exceeded

## Detailed description
Checks the storage of the SharePoint Online tenant on every run: the quota, how much is used, and the site collections that use the most. The full inventory is written to the run output. An alert email is sent only when the free storage drops below the low-storage limit or the licensed but unused storage exceeds the reclaimable limit.

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
Send an alert when the free tenant storage drops below this many gigabytes.

| Property | Value |
|----------|-------|
| Default Value | 200 |
| Required | true |
| Type | Int32 |

### AlertUnusedStorageLimitInGB
Send an alert when the licensed storage that no site uses exceeds this many gigabytes. That storage could be reclaimed.

| Property | Value |
|----------|-------|
| Default Value | 1024 |
| Required | false |
| Type | Int32 |

### TopSiteCount
How many of the largest site collections are listed.

| Property | Value |
|----------|-------|
| Default Value | 10 |
| Required | false |
| Type | Int32 |

### EmailFrom
Sender address of the alert email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AlertEmailTo
Address the alert goes to when a limit is exceeded.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AlertEmailSubject
Subject line of the alert email.

| Property | Value |
|----------|-------|
| Default Value | RealmJoin - SharePoint Online Storage Alert |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

