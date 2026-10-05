# Sync Shared Channel Owners (Scheduled)

Make a group's members owners of mapped teams and shared channels

## Detailed description
Shared channels do not inherit the owners of their team. For every team named in the mapping, the members of the mapped security group are made owners of the team and of each shared channel it hosts. It only adds, never removes; new shared channels are picked up on the next run. A dry run shows the changes without applying them. The report can be sent by email or provided as a download link.

## Where to find
Org \ General \ Sync Shared Channel Owners_Scheduled

## How it works

On each run the runbook:

1. Reads the team-name-to-owner-group mapping from the org setting `SharedChannelOwners.Mapping`.
2. For each entry, looks up the team by its **exact display name**.
3. Expands that entry's owner group to its transitive **user** members (guests are skipped - they cannot belong to a shared channel).
4. Ensures those users are owners of the team and of every **hosted** shared channel of the team.

The runbook is **add-only**: it never demotes or removes existing owners or members. Newly created shared channels are therefore picked up automatically on the next scheduled run, without disturbing anything already in place.

### Mapping configuration

The mapping lives centrally in the RealmJoin org settings (Runbook Customization → `Settings` → `SharedChannelOwners.Mapping`) so it is maintained once and shared by every schedule. It is a list of `{ TeamName, OwnerGroupId }` objects, where `TeamName` is the **exact team display name**. The hidden `TeamOwnerGroupMapping` parameter is injected from this setting; the runbook accepts it either as a structured array (recommended sub-setting form) or as a JSON string and normalizes both.

Ready-to-use example for the org settings:

```json
{
    "Settings": {
        "SharedChannelOwners": {
            "Mapping": [
                { "TeamName": "EXT Service A", "OwnerGroupId": "11111111-1111-1111-1111-111111111111" },
                { "TeamName": "EXT Service B", "OwnerGroupId": "22222222-2222-2222-2222-222222222222" }
            ]
        }
    }
}
```

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

Select **Dry run?** to log what would change without writing anything. Every run prints, up front, the teams it will process (with their owner group) and any configured team names that were not found; in a dry run the changes are listed as planned changes.

### Scheduling

Designed to run unattended on a schedule. Because configuration is centralized in the org settings and the runbook is add-only and idempotent, a single recurring schedule keeps all mapped teams and their shared channels in sync as people and channels come and go.

## Report delivery

Every run writes its results to the Output Data tab of the RealmJoin portal: a summary, the changes made (or planned in a dry run), the skipped teams and users with the reason (team not found, empty owner group, guest users, failed changes) and the owner assignments that were already in place. Each table can be exported to Excel there.

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link): a per-team summary and a per-change detail list, as CSV files and/or as an Excel workbook. With *Output Data only* selected, the results are read directly in the Output Data tab. Email delivery and download link generation are independent and can be combined; when both are selected, the download links are also embedded into the email.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

Schedules that were saved with the earlier delivery labels (for example *Email report*) keep their delivery. When such a schedule is opened for editing, the option shows *Output Data only* although the stored delivery stays active; select the delivery again before saving so that the dialog matches what the schedule does.

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The RealmJoin-branded email (sent via `Send-RjRbReportEmail`) contains the run statistics and the report files as attachments. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Channel.ReadBasic.All
  - ChannelMember.ReadWrite.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the download link options)


## Parameters
### TeamOwnerGroupMapping
List of team names with the security group whose members become owners. Taken from the tenant setting SharedChannelOwners.Mapping.

| Property | Value |
|----------|-------|
| Default Value | [] |
| Required | false |
| Type | Object |

### IncludeTeamOwners
Also makes the group members owners and members of the team itself, which is required for owning its channels.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### WhatIfMode
Only logs what would change without writing anything.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

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
| Default Value | shared-channel-owners |
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

