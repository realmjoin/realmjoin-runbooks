# Assign Groups By Template (Scheduled)

Assign cloud-only groups to many users based on a predefined template.

## Detailed description
Assign cloud-only groups to many users based on a predefined template.

## Where to find
Org \ General \ Assign Groups By Template_Scheduled

## Parameters
### SourceGroupId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### ExclusionGroupId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsTemplate
GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsString

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UseDisplaynames
$UseDisplayname = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

