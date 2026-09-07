# List Sharepoint Sitecollection Permission

List all members and administrators of a SharePoint Online site collection

## Detailed description
Connects to a SharePoint Online site collection using PnP.PowerShell with the system-assigned managed identity and retrieves the members of the site collection administrators, Owners group, Members group, and Visitors group. Each group's members are listed with their type, such as user, security group, or Entra ID group.

## Where to find
Org \ Collab \ List Sharepoint Sitecollection Permission

## Notes
Parameter Interactions:
- SiteUrl must point at a site collection root (e.g. https://contoso.sharepoint.com/sites/marketing),
  not a sub-site. A sub-site URL still returns results, but they describe the parent site
  collection - the runbook logs a warning when this happens.
- The Owners, Members, and Visitors groups are resolved via the site's associated-group properties,
  not by matching localized group names, so the report is accurate regardless of tenant language.
  Any of the three may be absent (common on Teams-connected sites) and is reported as "not configured"
  rather than causing a failure.

Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

## Permissions
### Application permissions
- **Type**: Office 365 SharePoint Online
  - Sites.FullControl.All

### Permission notes
Grant admin consent for the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (App ID 00000003-0000-0ff1-ce00-000000000000) to the Azure Automation account's system-assigned managed identity; this SharePoint app-only-via-managed-identity consent cannot be assigned through the standard Microsoft Graph app-role automation used for Graph permissions. See the runbook's documentation file for the assignment commands.


## Parameters
### SiteUrl
Full URL of the SharePoint Online site collection, for example https://contoso.sharepoint.com/sites/marketing

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

