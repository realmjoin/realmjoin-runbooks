# Invite External Guest Users

Invite external guest users to the organization

## Detailed description
This runbook invites an external user as a guest user in Microsoft Entra ID.
It can optionally add the invited user to a specified group.

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
Email address of the guest user to invite.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### InvitedUserDisplayName
Display name of the guest user.

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

