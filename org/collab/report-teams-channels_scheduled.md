## How it works

The runbook lists every Microsoft 365 group that is provisioned as a team, optionally narrowed by *Team name prefix*. For each team it reads the channels of the selected types and, for each channel, the member list.

- **Private channels** belong to one team; only their members see them, and they do not appear in the group view of the RealmJoin Portal or in the group membership of the team. This report is the way to see them at a glance.
- **Shared channels** are hosted by one team and can be shared with other teams and with people from other tenants. The report lists the shared channels a team hosts; channels shared into a team from elsewhere are not repeated under that team.

Every row names the team and its visibility, the channel, its type, whether it is archived, the creation date, the number of owners, members and external members, and the owners by name and email. With *List the members too?* set to yes, the members are listed by name as well; leave it off in large tenants to keep the report short.

Channels without any owner are listed in their own table and worksheet. A private or shared channel keeps working without an owner, but nobody can manage its membership from inside Teams, so such channels are the first candidates for cleanup.

### External members

A member whose tenant differs from the home tenant is marked *(external)* and counted in the *ExternalCount* column. Guest accounts of the home tenant are not marked, as they are members of the tenant directory.

### Teams and channels that cannot be read

A team whose channels cannot be read, for example because it was deleted while the report ran or because the team is archived and inaccessible, is listed in the *Teams not readable* table with the reason and does not stop the run. A channel whose member list cannot be read keeps its row with the reason in the *Note* column and is not counted as a channel without owner.

### Runtime

Channels and members are read through Graph batch requests, twenty at a time. A tenant with several thousand teams still takes a while; the job log shows the progress. Use *Team name prefix* to report on a subset.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *No report* selected, the results are read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

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

- The report is read-only. Owners and members of private and shared channels are changed in the Teams admin center or in Teams itself; the runbooks **Sync Channel Or Group Members (Scheduled)** and **Sync Shared Channel Owners (Scheduled)** cover the automated cases for shared channels.
- Standard channels are not listed; their membership equals the team membership, which the RealmJoin Portal shows.
- The member list of a shared channel contains its direct members. People who reach a shared channel through another team that the channel is shared with are not listed.
