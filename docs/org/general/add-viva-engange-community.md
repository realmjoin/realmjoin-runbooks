# Add Viva Engange Community

Create a Viva Engage (Yammer) community

## Detailed description
This runbook creates a Viva Engage community via the Yammer REST API using a stored developer token.
It can optionally assign owners and remove the initial API user from the resulting Microsoft 365 group.

## Where to find
Org \ General \ Add Viva Engange Community

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All


## Parameters
### CommunityName
Name of the community to create. Maximum length is 264 characters.

| Property | Value |
|----------|-------|
| Default Value | Sample Community |
| Required | true |
| Type | String |

### CommunityPrivate
If set to true, the community is created as private.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### CommunityShowInDirectory
If set to true, the community is visible in the directory.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### CommunityOwners
Comma-separated list of owner UPNs to add to the community.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### removeCreatorFromGroup
If set to true, removes the initial API user from the group when at least one other owner exists.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

