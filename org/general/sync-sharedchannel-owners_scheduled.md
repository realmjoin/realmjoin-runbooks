#### How it works

On each run the runbook:

1. Reads the prefix-to-owner-group mapping from the org setting `SharedChannelOwners.Mapping`.
2. Finds candidate teams whose display name starts with one of the configured prefixes and matches the selected visibility.
3. Resolves each matching team to exactly one mapping (see *Prefix matching*) and expands that mapping's owner group to its transitive **user** members (guests are skipped - they cannot belong to a shared channel).
4. Ensures those users are owners of the team and of every **hosted** shared channel of the team.

The runbook is **add-only**: it never demotes or removes existing owners or members. Newly created shared channels are therefore picked up automatically on the next scheduled run, without disturbing anything already in place.

#### Mapping configuration

The mapping lives centrally in the RealmJoin org settings (Runbook Customization → `Settings` → `SharedChannelOwners.Mapping`) so it is maintained once and shared by every schedule. It is a list of `{ TeamNamePrefix, OwnerGroupId }` objects (see the *Notes* section for a ready-to-use example). The hidden `TeamOwnerGroupMapping` parameter is injected from this setting; the runbook accepts it either as a structured array (recommended sub-setting form) or as a JSON string and normalizes both.

#### Prefix matching

Matching is deliberately strict so that, for example, the prefix `EXT` does **not** accidentally match a team called `External Collaboration`:

- A team matches a prefix only at a **word boundary** - the display name must equal the prefix exactly, or be the prefix followed by a space. Trailing spaces in the configured prefix are ignored (a prefix with or without a trailing space behaves identically), and matching is case-insensitive (consistent with Microsoft Graph).
- When several prefixes match the same team, the **most specific (longest) prefix wins**, and only that mapping's owner group is applied. A team is never processed by more than one mapping.

Example with the mapping `EXT` → Group A and `EXT Service` → Group B:

| Team display name | Result |
|---|---|
| `EXT Service` | Group B |
| `EXT Service Customer One` | Group B |
| `EXT Operations` | Group A |
| `External Collaboration` | no match (skipped) |
| `EXTService` | no match (no word boundary) |

#### Team selection and visibility

Candidate teams are discovered via a Graph `startswith(displayName, ...)` query per prefix (deduplicated), then filtered:

- Only Microsoft 365 groups that are provisioned as a **Team** are considered.
- The **`TeamVisibility`** parameter restricts processing to `Private` (includes hidden-membership teams), `Public`, or both. Org-wide teams are not specially handled yet; because their backing group visibility is `Public`, they are only in scope when `Public` or `PrivateAndPublic` is selected.

#### What gets changed

- **Team (optional, `IncludeTeamOwners`, default on):** the owner-group users are added as owners and members of the parent M365 group. Team membership is also the technical prerequisite for becoming a shared-channel owner, so this step enables the channel step.
- **Shared channels:** for every hosted shared channel (`membershipType eq 'shared'`), each owner-group user is ensured as a channel **owner** - added directly if absent, or promoted if already a member. If a direct owner-add is rejected (e.g. membership replication lag), the runbook falls back to adding the user as a member first and then promoting.

#### Dry run

Set **`WhatIfMode`** to log what would change without writing anything. In this mode the runbook prints, up front, the teams it would process (with their matched prefix and owner group) and the teams it found by prefix search but skipped at the word-boundary check.

#### Reporting (optional, both default off)

- **`SendEmailReport`** sends a RealmJoin-branded email (via `Send-RjReportEmail`) with run statistics and two CSV attachments: a per-team summary and a per-change detail list. The sender is taken from the `RJReport.EmailSender` setting.
- **`CreateDownloadLink`** uploads the same CSVs to a storage account and returns time-limited SAS download links (also embedded into the email when both options are enabled). The target storage account is taken from the `RJReport.StorageAccount.*` settings.

The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

#### Scheduling

Designed to run unattended on a schedule. Because configuration is centralized in the org settings and the runbook is add-only and idempotent, a single recurring schedule keeps all mapped teams and their shared channels in sync as people and channels come and go.
