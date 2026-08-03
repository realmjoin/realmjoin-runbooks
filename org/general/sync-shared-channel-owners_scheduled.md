## How it works

On each run the runbook:

1. Reads the team-name-to-owner-group mapping from the org setting `SharedChannelOwners.Mapping`.
2. For each entry, looks up the team by its **exact display name**.
3. Expands that entry's owner group to its transitive **user** members (guests are skipped - they cannot belong to a shared channel).
4. Ensures those users are owners of the team and of every **hosted** shared channel of the team.

The runbook is **add-only**: it never demotes or removes existing owners or members. Newly created shared channels are therefore picked up automatically on the next scheduled run, without disturbing anything already in place.

### Mapping configuration

The mapping lives centrally in the RealmJoin org settings (Runbook Customization → `Settings` → `SharedChannelOwners.Mapping`) so it is maintained once and shared by every schedule. It is a list of `{ TeamName, OwnerGroupId }` objects, where `TeamName` is the **exact team display name** (see the *Notes* section for a ready-to-use example). The hidden `TeamOwnerGroupMapping` parameter is injected from this setting; the runbook accepts it either as a structured array (recommended sub-setting form) or as a JSON string and normalizes both.

### Team matching

Each mapping entry targets one explicitly named team:

- A team is matched by its **exact display name** (case-insensitive, consistent with Microsoft Graph; surrounding whitespace in the configured name is ignored). Only that team is processed - there is no prefix or wildcard behaviour, so naming an entry `EXT Service A` never affects `EXT Service A Backup` or similar.
- Display names are not guaranteed unique in Entra ID. If several teams share the configured name, the owner group is applied to **all** of them. If no team matches, the entry is reported as *not found* and skipped.

### Team selection

For every configured `TeamName` the runbook runs a Graph `displayName eq '...'` lookup and keeps only Microsoft 365 groups that are provisioned as a **Team**.

### What gets changed

- **Team (optional, `IncludeTeamOwners`, default on):** the owner-group users are added as owners and members of the parent M365 group. Team membership is also the technical prerequisite for becoming a shared-channel owner, so this step enables the channel step.
- **Shared channels:** for every hosted shared channel (`membershipType eq 'shared'`), each owner-group user is ensured as a channel **owner** - added directly if absent, or promoted if already a member. If a direct owner-add is rejected (e.g. membership replication lag), the runbook falls back to adding the user as a member first and then promoting.

### Dry run

Set **`WhatIfMode`** to log what would change without writing anything. In this mode the runbook prints, up front, the teams it would process (with their owner group) and any configured team names that were not found.

### Reporting (optional, both default off)

- **`SendEmailReport`** sends a RealmJoin-branded email (via `Send-RjReportEmail`) with run statistics and two CSV attachments: a per-team summary and a per-change detail list. The sender is taken from the `RJReport.EmailSender` setting.
- **`CreateDownloadLink`** uploads the same CSVs to a storage account and returns time-limited SAS download links (also embedded into the email when both options are enabled). The target storage account is taken from the `RJReport.StorageAccount.*` settings.

The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

### Scheduling

Designed to run unattended on a schedule. Because configuration is centralized in the org settings and the runbook is add-only and idempotent, a single recurring schedule keeps all mapped teams and their shared channels in sync as people and channels come and go.
