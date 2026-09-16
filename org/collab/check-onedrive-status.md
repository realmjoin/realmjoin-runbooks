## Common use cases

- Check whether an active user's OneDrive is provisioned and, if so, whether it is locked or archived.
- Check whether a deleted user's OneDrive still exists in the tenant recycle bin, and when it is scheduled to be purged.

## Parameter behaviour

- `UserPrincipalName` accepts the UPN of an already deleted account, not only of active users. This is intentional: a user picker cannot select a deleted account, so the parameter is free text rather than a picker.
- For a deleted user, the recycle bin lookup matches on the deleted site's `SiteOwnerEmail`. A missing value or a prior UPN rename can cause a false "Not found" result.

The runbook is strictly read-only and makes no changes to the tenant.
