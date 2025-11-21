# Assign Groups By Template

Assign cloud-only groups to a user based on a predefined template.

## Detailed description
Assign cloud-only groups to a user based on a predefined template.

## Where to find
User \ General \ Assign Groups By Template

## Parameters
### UserId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
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

