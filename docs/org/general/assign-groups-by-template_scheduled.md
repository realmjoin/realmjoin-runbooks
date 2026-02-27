# Assign Groups By Template (Scheduled)

Assign cloud-only groups to many users based on a predefined template

## Detailed description
This runbook adds users from a source group to one or more target groups.
Target groups are provided via a template-driven string and can be resolved by group ID or display name.

## Where to find
Org \ General \ Assign Groups By Template_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All


## Parameters
### SourceGroupId
Object ID of the source group containing users to process.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ExclusionGroupId
Optional object ID of a group whose users are excluded from processing.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsTemplate
Template selector used by the portal to populate the GroupsString parameter.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsString
Comma-separated list of target groups (IDs or display names depending on UseDisplaynames).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UseDisplaynames
If set to true, GroupsString contains display names; otherwise it contains object IDs.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

