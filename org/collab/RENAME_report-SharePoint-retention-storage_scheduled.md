## Why this runbook exists

When a Microsoft Purview retention policy, a retention label or an eDiscovery hold applies to a SharePoint site or OneDrive, SharePoint creates the hidden **Preservation Hold library** in that site. Every deleted file and the original version of every edited file is kept there until the retention period ends. The library counts towards the storage of the site and of the tenant, and in sites with a lot of activity it can grow to a considerable share of the total storage without anyone noticing. This runbook makes that storage visible.

## Common use cases

- Scheduled weekly or monthly analysis of how much tenant storage is used by retention.
- Ad hoc analysis of a single site collection or OneDrive, for example when a site runs out of quota.
- Finding the sites where retention uses the most storage before reviewing the retention policies that apply to them.

## Ad hoc and scheduled analysis

- **Ad hoc:** enter the URL of one site collection or OneDrive in `SiteUrl`. Only that site is analyzed; `Scope` is ignored.
- **Scheduled:** leave `SiteUrl` empty and choose the `Scope`: all sites, SharePoint sites only or OneDrives only. In large tenants where a full scan exceeds the runtime limit, schedule one run for SharePoint sites and one for OneDrives.

## Output

- **Retention storage** – the totals of all sites in scope: retention storage, total site storage, the share of retention in percent, the number of retained files and how many sites have a Preservation Hold library. With `Scope` set to all sites this is the retention storage of the whole tenant.
- **Retention storage by site type** – the same totals for SharePoint sites and OneDrives.
- **Top sites by retention storage** – the sites with the most retention storage (10 by default, see `TopSiteCount`), each compared with the total storage of the site.
- **Sites that could not be read** and **Skipped sites** – listed whenever they occur; their retention storage is missing from the totals.
- **Download link** – the complete data set with one row per site in scope as CSV (enabled by default). The link expires after the number of days configured in `RJReport.StorageAccount.LinkExpiryDays`.
- **Email** – optional; sent with the CSV attached when `EmailTo` is set.

## How the values are measured

- The retention storage of a site is the size of its Preservation Hold library as shown on the *Storage Metrics* page of the site, including all versions of the retained files.
- The total storage of a site is the storage usage reported by the SharePoint admin center. This value is updated by SharePoint with a delay of up to a day, while the size of the Preservation Hold library is current. Right after large deletions the share can therefore briefly look too high.
- Sites without a Preservation Hold library have never been under retention and report 0.
- Only the Preservation Hold library of the root site of each site collection is measured.

## Resource usage

- In scheduled mode, sites that use no storage are not contacted at all, because they cannot hold retained content. This keeps runs over many unused OneDrives short.
- Every other site is contacted once. In large tenants a run can take several hours. Azure Automation cloud jobs are limited to three hours; split the run by `Scope` or use a Hybrid Runbook Worker for tenants with many thousand sites.
- A weekly or monthly schedule is usually sufficient, because retention storage changes slowly.

## Skipped sites

- Archived sites, sites locked with *NoAccess*, redirect sites and sites that are not active cannot be read and are listed as skipped.
- Sites locked as *ReadOnly* are still measured.

## Setup regarding the download link and email

- The download link needs the `RJReport.StorageAccount.*` tenant settings and the *Reader and Data Access* role for the managed identity on the storage account. Start the runbook without a download link if no storage account is configured.
- Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings, including the optional email branding.
