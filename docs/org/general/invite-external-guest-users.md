# Invite External Guest Users

Invites external guest users to the organization using Microsoft Graph.

## Detailed description
This script automates the process of inviting external users as guests to the organization. Optionally, the invited user can be added to a specified group.

## Where to find
Org \ General \ Invite External Guest Users

## Notes
You need to setup proper RunbookCustomization in the RealmJoin Portal to use this script.
An example would be looking like this:
"rjgit-org_general_invite-external-guest-users": {
    "Parameters": {
        "InvitedUserEmail": {
            "DisplayName": "Invitee's email address",
            "Mandatory": true
        },
        "InvitedUserDisplayName": {
            "DisplayName": "Invitee's display name",
            "Mandatory": true
        },
        "CallerName": {
            "Hide": true
        },
        "GroupId": {
            "Hide": true,
            "DefaultValue": "00000000-0000-0000-0000-000000000000"
        }
    }
}

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### InvitedUserEmail
The email address of the guest user to invite.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### InvitedUserDisplayName
The display name for the guest user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupId
The object ID of the group to add the guest user to.
If not specified, the user will not be added to any group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)

