# Add Viva Engange Community

Create a Viva Engage community with owners

## Detailed description
Creates a Viva Engage (Yammer) community with the given name, visibility and directory listing, and adds the named owners. The API user that creates the community can be removed from the resulting Microsoft 365 group once another owner exists.

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
Name of the community, up to 264 characters.

| Property | Value |
|----------|-------|
| Default Value | Sample Community |
| Required | true |
| Type | String |

### CommunityPrivate
A private community is visible only to its members.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### CommunityShowInDirectory
Lists the community in the Viva Engage directory so people can find it.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### CommunityOwners
Sign-in names of the owners, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### removeCreatorFromGroup
Takes the API user that created the community out of the group, as long as at least one other owner exists.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

