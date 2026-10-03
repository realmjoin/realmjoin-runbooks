# List Sharepoint Sitecollection Permission

List the administrators and members of a SharePoint site

## Detailed description
Shows who has access to a SharePoint Online site collection: the site collection administrators and the members of the Owners, Members and Visitors groups. Each entry shows its type, such as user, Entra ID group, security group or SharePoint group. Nothing is changed.

## Where to find
Org \ Collab \ List Sharepoint Sitecollection Permission

## Parameter behaviour

- `SiteUrl` must point at a site collection root (for example `https://contoso.sharepoint.com/sites/marketing`), not at a sub-site. A sub-site URL still returns results, but they describe the parent site collection; the runbook logs a warning when this happens.
- The Owners, Members and Visitors groups are resolved via the site's associated-group properties, not by matching localized group names, so the report is accurate regardless of the tenant language. Any of the three groups may be absent (common on Teams-connected sites) and is then reported as "not configured" instead of causing a failure.


## Permissions
### Application permissions
- **Type**: Office 365 SharePoint Online
  - Sites.FullControl.All

### Permission notes
Grant admin consent for the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (App ID 00000003-0000-0ff1-ce00-000000000000) to the Azure Automation account's system-assigned managed identity; this SharePoint app-only-via-managed-identity consent cannot be assigned through the standard Microsoft Graph app-role automation used for Graph permissions. See the runbook's documentation file for the assignment commands.


## Parameters
### SiteUrl
Full URL of the site, for example https://contoso.sharepoint.com/sites/marketing.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

