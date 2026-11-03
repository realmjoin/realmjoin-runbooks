## How it works

This scheduled runbook mirrors the membership of a **source** object into a **target** object in a
single direction per run. On each run it:

1. Resolves the source and target objects for the selected direction.
2. Reads the current member set of both sides.
3. Adds every source member that is missing from the target.
4. Optionally removes every target member that does not exist in the source (mirror mode).

### Directions

**Direction** selects what is synced into what:

- **`SharedChannelToGroup`** - the members of a Teams shared channel are copied into a target security group.
- **`GroupToGroup`** - the members of a source group are copied into a target group (for example a Microsoft 365 group into a security group, or the reverse by swapping source and target).
- **`GroupToSharedChannel`** - the members of a source group are copied into a Teams shared channel.

### Adding and removing

Adding missing members is always performed. Removing members that exist only in the target is **opt-in**
via **Remove members missing in the source?** (`RemoveExtraMembers`, default off). With removal enabled, the target is mirrored exactly against the
source; with it disabled, the runbook is add-only.

If a member list cannot be read completely from Microsoft Graph, the run fails before any member is added
or removed, so an incomplete source never leads to removals.

### Group member expansion

Group members on the source side are resolved **transitively**, so users that are members through nested
groups are included. On the target side only **direct** members are considered, because add and remove
operations act on direct membership.

### Guest handling

**Include guest users?** (`IncludeGuests`, default off) controls whether guest users take part in the sync. When it is off, guests
are skipped on both sides and are never added or removed. Shared channels frequently reject guests, so
this is off by default.

### Shared channel specifics

- When a group is synced **into** a shared channel, team membership is a prerequisite for channel
  membership, so the runbook first ensures the user is a member of the host team and then adds the user
  to the channel.
- When members are **removed** from a shared channel, only the channel membership is removed by default.
  Enable **Also remove from the host team?** (`RemoveFromTeam`) to also remove the user from the host team membership.

### Dry run

Select **Dry run?** (`WhatIfMode`) to log what would change without writing anything. The Output Data tables then list the planned changes.

### Scheduling

Designed to run unattended on a schedule. Because the runbook is idempotent, a single recurring schedule
keeps the target in sync with the source as members come and go.

## Report delivery

Every run writes its results to the Output Data tab of the RealmJoin portal:

- **Summary** - mode (live or dry run), direction, source and target, the member counts of both sides,
  the members added and removed, and whether removal and guests were enabled (the same figures as in the
  report email).
- **Actions** - one row per change (target, user, user ID, add or remove, mode); in a dry run these are
  the planned changes. Failed changes are not listed; they appear in the runbook output. When nothing
  changes, a status line replaces the table.

Each table can be exported to Excel there.

Report files are only generated when a delivery method is selected via the **Report delivery** option
(email and/or download link): the per-change list as a CSV file and/or as an Excel workbook with the
worksheet *Actions*, as chosen in **Report file format**. With *Output Data only* selected, the results
are read directly in the Output Data tab. Email delivery and download link generation are independent
and can be combined; when both are selected, the download links are also embedded into the email.

For the download link, the report files are uploaded to the Azure storage account configured in the
`RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The
storage upload authenticates with the Automation account's managed identity; that identity needs the
**Reader and Data Access** RBAC role on the target storage account (this is an Azure RBAC assignment,
not a Graph application permission).

Schedules that were saved before the **Report delivery** option existed keep their delivery, because they
pass `SendEmailReport` and `CreateDownloadLink` directly. When such a schedule is opened for editing, the
option shows *Output Data only*. Select the delivery again first: as soon as another choice in the dialog
changes, such as **Direction**, the dialog applies *Output Data only*, and saving then turns the email and
the download link off.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email &
download link* is selected as report delivery; a recipient is then required. The RealmJoin-branded email
(sent via `Send-RjRbReportEmail`) contains the run statistics and the report files as attachments. The
sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to
configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).
