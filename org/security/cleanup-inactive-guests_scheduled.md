## Guest lifecycle

This runbook works together with **Remove Inactive Guests From SharePoint** (Org/Collab). With the default values a guest without sign-in goes through these stages:

| Days without sign-in | Runbook | Action |
| --- | --- | --- |
| 14 (`DisableAfterDays`) | Cleanup Inactive Guests | Account is disabled |
| 90 (`RemoveAfterDays`) | Remove Inactive Guests From SharePoint | Guest is removed from all SharePoint sites and OneDrives |
| 180 (`DeleteAfterDays`) | Cleanup Inactive Guests | Disabled account is deleted |

Deleting a guest without the SharePoint cleanup leads to a *site user ID mismatch* when the same person is invited again later. See [Fix site user ID mismatch in SharePoint or OneDrive](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/sharing-and-permissions/fix-site-user-id-mismatch).

The two runbooks do not exchange any state; the order follows only from the configured days. Keep `RemoveAfterDays` of Remove Inactive Guests From SharePoint well below `DeleteAfterDays`, so the SharePoint cleanup has run at least once before the account is deleted.

Recommended schedule: this runbook daily, Remove Inactive Guests From SharePoint weekly. Use the same `IgnoreGroupIds` in both runbooks.

## How the last sign-in is determined

- The most recent of the interactive, non-interactive and last successful sign-in (`signInActivity`) is used.
- Guests that never signed in (for example invitations that were never redeemed) are measured from their creation date, so a newly invited guest is not disabled right away.
- Reading `signInActivity` requires an Entra ID P1 license in the tenant.

## Behavior

- Only accounts with `userType` *Guest* are evaluated.
- A guest is only deleted when it is already disabled. An enabled guest that exceeds `DeleteAfterDays` is disabled first and deleted in a later run.
- A guest who was re-enabled manually but still has no new sign-in is disabled again in the next run. Add such guests to an ignore group instead.
- If an ignore group cannot be read, the run is aborted so that no protected guest is processed.
- Deleted guests are moved to the Entra ID recycle bin and can be restored for 30 days.
## Recommended first run

1. Run with *Dry run* enabled (default) and a download link or email recipient.
2. Review the CSV report.
3. Disable the dry run only after the list has been reviewed.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting. See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings, including the optional email branding.
