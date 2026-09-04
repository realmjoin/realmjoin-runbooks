## How it works

This runbook looks up the OneDrive (personal site) status of a single user, identified by their
user principal name. It first checks whether an active site collection still exists for the user;
if none is found, it searches the tenant's site recycle bin for a matching deleted OneDrive.

### Interpreting the results

The runbook reports one of the following outcomes:

- **Active** – the OneDrive site collection exists, is not archived, and is not locked.
- **Active, but locked** – the site collection exists but its lock state is `ReadOnly` or
  `NoAccess`, meaning the user (and in some cases administrators) cannot access content normally.
- **Archived** – the site collection exists and has been placed in an archived state. See the
  archive states below for the exact value.
- **In the recycle bin** – no active site collection exists, but a matching entry was found in the
  tenant's site recycle bin. The report includes the deletion time, which determines when the site
  is permanently purged (93 days after deletion by default, unless the tenant retention period has
  been changed).
- **Not found** – no active site collection and no matching recycle bin entry were found. This
  means either the OneDrive was **never provisioned** for this user, or it **was already
  permanently purged** after the retention period elapsed. These two cases cannot be distinguished
  from the recycle bin alone, since a purged site leaves no trace.

### Archive states

`ArchiveStatus` is reported verbatim from SharePoint and uses a fixed set of values. Only the three
archived values cause the overall status to be reported as archived:

| `ArchiveStatus` | Reported as | Meaning |
|---|---|---|
| `NotArchived` | Active | The normal state of a live OneDrive. Not archived in any way. |
| `FullyArchived` | Archived | Fully moved to archive storage. Content is not accessible until the site is reactivated. |
| `RecentlyArchived` | Archived (recently archived) | Archived within the last few days, so reactivation is still fast and inexpensive. |
| `Reactivating` | Reactivating from archive | Transitional — the site is currently being brought back out of the archive. |
| `Archived` | Archived | Generic archived value. |

A site that reports no archive status at all (older tenants, or site types that do not surface the
property) is treated as `NotArchived`. If SharePoint ever returns a value outside this set, the
runbook reports it verbatim as `Active (unknown archive status '<value>')` rather than guessing —
so a new value added by Microsoft is visible instead of being silently misclassified.

Note that archiving a site typically also sets its lock state to `ReadOnly`. The runbook therefore
evaluates the archive state **before** the lock state and combines the two, so an archived OneDrive
is never reported as merely "Active (read-only)".

### Checking deleted users

`UserPrincipalName` can be the UPN of an account that has already been deleted from Entra ID. This
is a supported and expected scenario: a deleted user's OneDrive commonly still exists in the
recycle bin for some time after the account itself is gone, and this runbook is one of the few ways
to check its remaining retention window before it is purged.

Because the deleted user's profile no longer exists, the recycle bin lookup for a deleted user
matches on the deleted site's `SiteOwnerEmail` property instead — this is the only key still
available once the account itself is gone.

### Limitations

The tenant site recycle bin is queried with a maximum of 1000 entries. In a tenant with more than
1000 deleted OneDrive sites currently in the recycle bin, a matching entry could in principle fall
outside this limit and be reported as **Not found** even though it still exists.

For a deleted user, the match against the recycle bin relies entirely on `SiteOwnerEmail`:

- If `SiteOwnerEmail` was not populated on the deleted-site record (this is not always set, e.g.
  for very old deletions or sites carried over from a tenant migration), the OneDrive will not be
  found and is reported as **Not found** even though it is still in the recycle bin.
- If the user was renamed (their UPN changed) after the OneDrive was provisioned but before the
  account was deleted, the UPN passed to this runbook may not match the recorded
  `SiteOwnerEmail`, with the same result.
- In both cases, a **Not found** result for a deleted user is not a guarantee that the OneDrive is
  gone — verify directly in the SharePoint admin center's "Deleted sites" view before concluding
  the data is unrecoverable.


### Granting SharePoint access to the managed identity

The SharePoint application permission this runbook needs cannot be granted through the standard
automated Entra app-role assignment flow used for Microsoft Graph permissions. Instead, it must be
granted manually to the Automation account's system-assigned managed identity through the
SharePoint admin center or the appropriate PnP/SharePoint management tooling, following your
organization's process for granting SharePoint application-level access to a service principal.
Repeat this step whenever the runbook is deployed to a new tenant or Automation account.
