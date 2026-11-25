## How it works

The runbook lists every team of the tenant, or only the selected teams, and reads the shared channels each team hosts. The team list comes from the Teams service itself, so old teams whose group is not marked as a team are included as well. For every shared channel it reads the direct members, the complete member list including people who reach the channel through another team, and the teams the channel is shared with.

Every member row names the team and the channel, the member with email address, the role in the channel, how the person reaches the channel, the user type and the organization the account belongs to. The *Shared channels* table adds one row per channel with the number of members, owners, guests, external members and members who only come through a team, the teams the channel is shared with, whether it is archived and when it was created.

### Channels and table layout

- **All shared channels, one table** - every member of every shared channel in one table *Shared channel members*, with team and channel as columns.
- **All shared channels, one table per channel** - one table per shared channel in the Output Data tab and one worksheet per channel in the Excel workbook. The CSV file still holds all members in one file with team and channel as columns.
- **Shared channels by name, one table** - only the channels entered in *Shared channel names (comma-separated)*, for example `Project X, Partner Hub`. Each name is compared in full, upper and lower case do not matter. The members of all named channels appear in one table with team and channel as columns.

Names without a matching channel are listed in the console output, in the *Channel names not found* row of the summary and in the report email; the run continues with the channels it found. When none of the names matches, the run fails and lists the shared channels it found. A channel whose name contains a comma cannot be selected by name; use one of the other options for it.

### Limit to these teams

*Limit to these teams* is offered with every option and accepts several teams. Leave it empty to read all teams of the tenant. With teams selected, only the shared channels hosted by those teams are read and reported, for example all shared channels of two teams with one table per channel, or channels given by name searched only in those teams. Reading a few teams is also much faster than reading all teams.

A selected group that is not a team or cannot be read is listed in the *Teams not readable* table and skipped; the run fails only when none of the selected groups is a readable team.

### Direct and indirect members

A shared channel can be shared with teams, in the same tenant or in another one, and also with the team that hosts it. All members of such a team can open the channel without being added to it. The *SharedWithTeams* column lists these teams and marks the host team with *(host team)*. The *Membership* column shows the way a person reaches the channel:

- **Direct** - added to the channel itself.
- **Via team** - only through a team the channel is shared with; *ViaTeams* names that team.
- **Direct and via team** - both.

Channel owners are always direct members. People who only come through a team are listed with the role *Member* (or *Guest*), whatever role they hold in their own team.

### Guests and external members

- **Internal** - an account of the home tenant.
- **Guest** - a guest account in the home tenant (B2B collaboration). Teams does not let guests join shared channels, so this value only appears when Graph reports a member with the guest role.
- **External** - a person from another tenant who joined the channel directly or through a team of their organization (B2B direct connect). The *Organization* column shows the name of that organization; without the optional `CrossTenantInformation.ReadBasic.All` permission it shows the tenant ID.

### Table and worksheet names

With *All channels, one table each*, the channel name becomes the table and worksheet name. Excel allows at most 31 characters and none of `\ / ? * [ ] :`, so longer names are shortened and channels with the same name get a counter such as `Project (2)`. The *Table* column of the *Shared channels* table shows which table belongs to which team and channel.

### Gaps in the report

The runbook never shortens a list silently. Whatever it cannot read is named, and the run continues with the rest:

- **Team not readable** - a team whose channel list cannot be read, or whose list is cut off because a further page fails, is listed in the *Teams not readable* table with the reason. Selected groups that are not teams are listed there as well.
- **Members not readable** - a channel whose member lists cannot be read at all keeps its row in *Shared channels* with the reason in the *Note* column and is counted in *Channels not readable*.
- **Incomplete member list** - when the members who come through a team cannot be read, or the complete member list is cut off, the reason is in the *Note* column and the channel is counted in *Incomplete member lists*. Direct members are still listed.
- **No response** - a request that Graph does not answer is treated like a failed one.

When any of these counters is above zero, the job log shows a warning that the report is incomplete.

### Members of teams from other organizations

Graph returns the complete member list of a shared channel page by page, the members of teams from other organizations last. In some tenants it refuses those later pages (HTTP 400), so the people who reach a channel through a partner organization's team would be missing. In that case, and when the complete list cannot be read at all, the runbook reads the members of each affected shared team on its own and adds them as *Via team*. The *Note* column then says that the members were read per team; the channel is not counted as incomplete. Only when a shared team cannot be read this way either, the note names that team and the channel counts in *Incomplete member lists*.

### Runtime

Channels and members are read through Graph batch requests, twenty at a time: one request per team and three per shared channel. A tenant with several thousand teams still takes a while; the job log shows the progress. Use *Limit to these teams* to read only the teams you need.

## Report delivery

The results always appear as named tables in the Output Data tab of the run in the RealmJoin portal. Report files are only generated when the **Report delivery** option includes an email and/or a download link; *Output Data only* creates no report files. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Reader and Data Access** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Notes and limitations

- The report lists the shared channels hosted in this tenant. Shared channels that another organization hosts and shares with a team of this tenant are not listed, so people of this tenant who reach a channel of another organization do not appear.
- People who were invited to a shared channel but have not accepted yet are not members and do not appear; Graph does not list pending invitations.
- Deleted shared channels (restorable for 30 days) are not listed. Archiving a team removes the sharing with other teams, so the members who came through those teams no longer appear.
- *Limit to these teams* only offers groups that are marked as teams. An old team without this mark is still part of the report when the field is left empty.
- The report is read-only. Members of shared channels are changed in Teams or in the Teams admin center; the runbooks **Sync Channel Or Group Members (Scheduled)** and **Sync Shared Channel Owners (Scheduled)** cover the automated cases.
- For an overview of private and shared channels with their owners, use **Report Teams Channels (Scheduled)**.
