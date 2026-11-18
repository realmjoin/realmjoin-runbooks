## Why this runbook exists

SharePoint keeps an entry for every user in the user information list of each site collection and OneDrive the user has accessed. The entry stores the account's ID (PUID). When a user account is deleted and recreated with the same user principal name, the new account gets a new PUID, but the sites still hold the old one and access fails with a *site user ID mismatch*. See [Fix site user ID mismatch in SharePoint or OneDrive](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/sharing-and-permissions/fix-site-user-id-mismatch).

For guests this can be prevented in advance with **Remove Inactive Guests From SharePoint**. This runbook fixes the mismatch after it has occurred, for members and guests.

## How it works

1. The current PUID of each selected user is read from the SharePoint user profile (property `SID`). Users without a profile are skipped and listed in the *Users* table.
2. Every site in scope is checked for an entry with the same login name but a different PUID.
3. Without dry run the stale entry is removed with `Remove-PnPUser`. If the entry is a site collection administrator, that role is removed first. SharePoint adds the user again with the correct PUID on the next access.

## What is not restored

- Permissions and SharePoint group memberships of a removed entry are **not** restored. The groups are listed in the *SharePointGroups* column of the report so they can be granted again. Permissions granted directly to the user (outside of a group) are not listed.
- Site collection administrator roles are not restored; the *IsSiteAdmin* column shows where the user was an administrator.

## Entries that are not removed

- The old OneDrive of the deleted account is owned by the same user principal name. The primary owner cannot be removed, so the entry is reported as *Skipped*. The recreated account gets a new OneDrive.
- On read-only sites the mismatch is reported but not removed.
- Sites with lock state *NoAccess*, archived sites and redirect sites are not scanned and are listed in the *Skipped sites* table. Sites whose users cannot be read for other reasons are reported as *ReadFailed*.

## Resource usage

- Every site in scope is visited once. Up to `BulkLoadThreshold` users (default 10) are looked up individually per site; above that, all users of a site are loaded once and matched against all selected users.
- In large tenants a run can take several hours. Azure Automation cloud jobs are limited to three hours; limit the scope (e.g. *OneDrives only*) or use a Hybrid Runbook Worker for tenants with many thousand sites.

## Recommended first run

1. Run with *Dry run* enabled (default) and a download link or email recipient.
2. Review the mismatches and note the SharePoint groups that have to be granted again.
3. Disable the dry run only after the list has been reviewed.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting. See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings, including the optional email branding.
