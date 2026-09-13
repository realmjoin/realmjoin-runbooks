# Check Onedrive Status

Check the status of a user's OneDrive

## Detailed description
Connects to the SharePoint admin center using the managed identity and retrieves the status of the specified user's personal site (OneDrive). Reports whether the site is active or archived, its lock state, and whether it resides in the tenant recycle bin. The runbook is read-only and makes no changes to the site or its state.

## Where to find
Org \ Collab \ Check Onedrive Status

## Notes
Common Use Cases:
- Check whether an active user's OneDrive is provisioned, and if so, whether it is locked
  or archived.
- Check whether a deleted user's OneDrive still exists in the tenant recycle bin, and when
  it is scheduled to be purged.

Parameter Interactions:
- UserPrincipalName accepts the UPN of an already-deleted account, not only active users.
  This is intentional: a user picker cannot select a deleted account, so the parameter is
  free text rather than a picker.
- For a deleted user, recycle bin matching relies on the deleted site's SiteOwnerEmail; a
  missing value or a prior UPN rename can cause a false "Not found" result.

This runbook is strictly read-only and makes no changes to the tenant.

Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

## Permissions
### Application permissions
- **Type**: Office 365 SharePoint Online
  - Sites.FullControl.All

### Permission notes
SharePoint Online: grant 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000) to the Automation account's system-assigned managed identity. This SharePoint app-only grant cannot be made through the standard Entra app-role-assignment automation used for Microsoft Graph and must be assigned manually per tenant (e.g. via the SharePoint admin center or the Grant-PnPAzureADAppSitePermission equivalent for managed identities).


## Parameters
### UserPrincipalName
User principal name of the user whose OneDrive status should be checked. This parameter accepts the UPN of a user whose account has already been deleted, as deleted users' OneDrive sites may still exist in the tenant recycle bin.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

