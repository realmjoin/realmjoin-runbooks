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
