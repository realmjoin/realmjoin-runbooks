## Parameter behaviour

- `SiteUrl` must point at a site collection root (for example `https://contoso.sharepoint.com/sites/marketing`), not at a sub-site. A sub-site URL still returns results, but they describe the parent site collection; the runbook logs a warning when this happens.
- The Owners, Members and Visitors groups are resolved via the site's associated-group properties, not by matching localized group names, so the report is accurate regardless of the tenant language. Any of the three groups may be absent (common on Teams-connected sites) and is then reported as "not configured" instead of causing a failure.
