## How it works

This scheduled runbook mirrors the membership of a **source** object into a **target** object in a
single direction per run. On each run it:

1. Resolves the source and target objects for the selected direction.
2. Reads the current member set of both sides.
3. Adds every source member that is missing from the target.
4. Optionally removes every target member that does not exist in the source (mirror mode).

### Directions

The `Direction` parameter selects what is synced into what:

- **`SharedChannelToGroup`** - the members of a Teams shared channel are copied into a target security group.
- **`GroupToGroup`** - the members of a source group are copied into a target group (for example a Microsoft 365 group into a security group, or the reverse by swapping source and target).
- **`GroupToSharedChannel`** - the members of a source group are copied into a Teams shared channel.

### Adding and removing

Adding missing members is always performed. Removing members that exist only in the target is **opt-in**
via `RemoveExtraMembers` (default off). With removal enabled, the target is mirrored exactly against the
source; with it disabled, the runbook is add-only.

### Group member expansion

Group members on the source side are resolved **transitively**, so users that are members through nested
groups are included. On the target side only **direct** members are considered, because add and remove
operations act on direct membership.

### Guest handling

`IncludeGuests` (default off) controls whether guest users take part in the sync. When it is off, guests
are skipped on both sides and are never added or removed. Shared channels frequently reject guests, so
this is off by default.

### Shared channel specifics

- When a group is synced **into** a shared channel, team membership is a prerequisite for channel
  membership, so the runbook first ensures the user is a member of the host team and then adds the user
  to the channel.
- When members are **removed** from a shared channel, only the channel membership is removed by default.
  Enable `RemoveFromTeam` to also remove the user from the host team membership.

### Dry run

Set `WhatIfMode` to log what would change without writing anything.

### Reporting (optional, both default off)

- **`SendEmailReport`** sends a RealmJoin-branded email (via `Send-RjReportEmail`) with run statistics and
  a CSV attachment listing every individual change. The sender is taken from the `RJReport.EmailSender`
  setting.
- **`CreateDownloadLink`** uploads the same CSV to a storage account and returns a time-limited SAS
  download link (also embedded into the email when both options are enabled). The target storage account
  is taken from the `RJReport.StorageAccount.*` settings.

The storage upload authenticates with the Automation account's managed identity; that identity needs the
**Storage Blob Data Contributor** RBAC role on the target storage account (this is an Azure RBAC
assignment, not a Graph application permission).

### Scheduling

Designed to run unattended on a schedule. Because the runbook is idempotent, a single recurring schedule
keeps the target in sync with the source as members come and go.
