# Report Teams Channels (Scheduled)

List private and shared channels of all teams with their owners

## Detailed description
Walks through every team in the tenant and lists its private and shared channels with the team they belong to, their owners and, if wanted, their members. Private channels are not visible in the group view of the RealmJoin Portal, so this report shows who owns and who can access them. Channels without any owner are listed separately. The report can be sent by email or provided as a download link.

## Where to find
Org \ Collab \ Report Teams Channels_Scheduled

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Channel.ReadBasic.All
  - ChannelMember.Read.All
  - Group.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*


## Parameters
### IncludePrivateChannels
Lists the private channels hosted by each team.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeSharedChannels
Lists the shared channels hosted by each team. Members from other tenants are marked as external.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMembers
Also lists the members of each channel by name. Off lists the owners only, which keeps the report short in large tenants.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TeamNamePrefix
Only teams whose name starts with this text. Leave empty for all teams.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendEmailReport
Send the report to the recipient email address.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | report-teams-channels |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

