## Why this runbook exists

SharePoint keeps an entry for every user in the user information list of each site collection and OneDrive. When a guest account is deleted in Entra ID and the same person is invited again later, the new account no longer matches the stored entry and access fails with a *site user ID mismatch*. Removing the guest from all sites before the account is deleted prevents this. See [Fix site user ID mismatch in SharePoint or OneDrive](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/sharing-and-permissions/fix-site-user-id-mismatch).

The removal is equivalent to `Remove-SPOUser -Site <url> -LoginName <upn>` and is done with PnP PowerShell (`Remove-PnPUser`) for every site collection including OneDrives.

## Interaction with Cleanup Inactive Guests

- **Cleanup Inactive Guests** (Org/Security) disables inactive guests and later deletes them.
- This runbook processes guests that are **disabled** and have no sign-in for `RemoveAfterDays` days.
- The two runbooks do not exchange any state and nothing is written to the guest account. The order follows only from the configured days: keep `RemoveAfterDays` well below `DeleteAfterDays` of Cleanup Inactive Guests, so the guest is removed from SharePoint before the account is deleted.
- A disabled guest is processed in every run until Cleanup Inactive Guests deletes it. Sites from which it was already removed simply no longer list it.
- Use the same `IgnoreGroupIds` in both runbooks.

## Resource usage

- All guests are determined first via Microsoft Graph. When no guest needs to be removed, SharePoint is not contacted at all.
- Otherwise every site collection and OneDrive is visited exactly once. The user information list of each site is read once and matched against all guests together, so the run time depends on the number of sites, not on the number of guests.
- In large tenants a run can take several hours. Azure Automation cloud jobs are limited to three hours; use a Hybrid Runbook Worker for tenants with many thousand sites.
- A weekly schedule is usually sufficient.

## Skipped sites

- Sites with lock state *ReadOnly* or *NoAccess*, archived sites and redirect sites are skipped, because they are not writable. They are listed in the *Skipped sites* table and CSV.
- Sites whose users cannot be read for other reasons are reported as *ReadFailed* and should be checked manually.
- If the removal from a site fails, the next run tries again.

## Recommended first run

1. Run with *Dry run* enabled (default) and a download link or email recipient.
2. Review the CSV reports (guests, site removals, skipped sites).
3. Disable the dry run only after the list has been reviewed.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting. See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings, including the optional email branding.
