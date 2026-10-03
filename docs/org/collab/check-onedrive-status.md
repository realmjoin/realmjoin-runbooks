# Check Onedrive Status

Check whether a user's OneDrive is active, locked or deleted

## Detailed description
Looks up the personal OneDrive site of a user and reports whether it is active or archived, whether it is locked, and whether it sits in the tenant recycle bin. Works for users whose account has already been deleted, as their OneDrive may still be in the recycle bin. Nothing is changed.

## Where to find
Org \ Collab \ Check Onedrive Status

## Common use cases

- Check whether an active user's OneDrive is provisioned and, if so, whether it is locked or archived.
- Check whether a deleted user's OneDrive still exists in the tenant recycle bin, and when it is scheduled to be purged.

## Parameter behaviour

- `UserPrincipalName` accepts the UPN of an already deleted account, not only of active users. This is intentional: a user picker cannot select a deleted account, so the parameter is free text rather than a picker.
- For a deleted user, the recycle bin lookup matches on the deleted site's `SiteOwnerEmail`. A missing value or a prior UPN rename can cause a false "Not found" result.

The runbook is strictly read-only and makes no changes to the tenant.


## Permissions
### Application permissions
- **Type**: Office 365 SharePoint Online
  - Sites.FullControl.All

### Permission notes
SharePoint Online: grant 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000) to the Automation account's system-assigned managed identity. This SharePoint app-only grant cannot be made through the standard Entra app-role-assignment automation used for Microsoft Graph and must be assigned manually per tenant (e.g. via the SharePoint admin center or the Grant-PnPAzureADAppSitePermission equivalent for managed identities).


## Parameters
### UserPrincipalName
User principal name of the user whose OneDrive is checked. Deleted users are accepted.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

