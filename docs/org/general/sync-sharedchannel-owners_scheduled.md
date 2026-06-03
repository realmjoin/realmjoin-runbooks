# Sync Sharedchannel Owners (Scheduled)

Ensure a security group's members are owners of mapped Teams and their shared channels.

## Detailed description
Teams shared channels do not inherit ownership from their parent team. This scheduled runbook closes
that gap: for each team named in a mapping, it ensures the members of a mapped security group are owners
of the team and of every shared channel the team hosts. The team-name-to-owner-group mapping is
maintained centrally as a RealmJoin org setting. The runbook is add-only - existing owners and members
are never removed - so newly created shared channels are simply picked up on the next run. It can
optionally email a report and/or upload the CSV results as a download link. See the accompanying
documentation for the mapping rules and configuration.

## Where to find
Org \ General \ Sync Sharedchannel Owners_Scheduled

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


## Notes
Configure the mapping once centrally (Runbook Customization -> Settings) as a structured sub-setting under
"SharedChannelOwners.Mapping". Each entry names a team by its exact display name. The hidden
TeamOwnerGroupMapping parameter is injected from it at runtime.
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

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
  - Channel.ReadBasic.All
  - ChannelMember.ReadWrite.All
  - Mail.Send


## Parameters
### TeamOwnerGroupMapping
Mapping of an exact team display name to an owner security group object id, e.g.
[{ "TeamName": "EXT Service A", "OwnerGroupId": "00000000-0000-0000-0000-000000000000" }].
Hidden parameter, bound to the org Setting "SharedChannelOwners.Mapping". The RealmJoin portal injects
that value; the runbook accepts it either as the deserialized object/array (structured sub-settings) or
as a JSON string and normalizes both.

| Property | Value |
|----------|-------|
| Default Value | [] |
| Required | false |
| Type | Object |

### IncludeTeamOwners
When enabled (default), the owner-group members are also ensured as owners and members of the parent
team itself (M365 group owners/members). Team membership is also the prerequisite for channel ownership.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### WhatIfMode
When enabled, the runbook only logs the changes it would make without writing anything.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SendEmailReport
When enabled, a RealmJoin-branded email report is sent via Send-RjReportEmail after the run. The body
contains run statistics and two CSV attachments (per-team summary and per-change detail).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient email address(es) for the report (comma-separated). Only used when SendEmailReport is enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
Sender mailbox for the report. Bound to the org Setting "RJReport.EmailSender".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateDownloadLink
When enabled, the CSV report(s) are uploaded to a storage account and a time-limited download link is
returned (and included in the email report if that is also enabled). Default off.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | shared-channel-owners |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account. Bound to "RJReport.StorageAccount.ResourceGroup".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account used for the upload. Bound to "RJReport.StorageAccount.StorageAccountName".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Days until the generated download link expires. Bound to "RJReport.StorageAccount.LinkExpiryDays".

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

