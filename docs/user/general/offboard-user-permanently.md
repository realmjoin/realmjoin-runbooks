# Offboard User Permanently

Permanently offboard this user

## Detailed description
Offboards this user for good: access is revoked, the account is disabled or deleted, licenses and groups are adjusted, and the group memberships can be exported before they are changed. Group ownerships, direct reports and sponsorships of guests can be handed over to a replacement. A deleted account can be restored for 30 days only.

## Where to find
User \ General \ Offboard User Permanently

## Preset the offboarding policy via tenant settings

Most switches of this runbook are backed by tenant settings, so an organization can fix its offboarding policy once and hide the corresponding fields from the operators. The example below presets every switch and hides the fields; keep only the fields the operators should still decide per run.

```json
{
    "Settings": {
        "OffboardUserPermanently": {
            "userTypeRestriction": 0,
            "deleteUser": true,
            "disableUser": true,
            "revokeAccess": true,
            "exportGroupMemberships": true,
            "licensesMode": 0,
            "groupsMode": 0,
            "groupToAdd": "",
            "groupsToRemovePrefix": "",
            "replaceManagerReferences": true,
            "replaceSponsorReferences": true
        },
        "RJReport": {
            "StorageAccount": {
                "ResourceGroup": "rj-test-runbooks-01",
                "StorageAccountName": "rjrbexports01",
                "LinkExpiryDays": 6
            }
        }
    },
    "Runbooks": {
        "rjgit-user_general_offboard-user-permanently": {
            "ParameterList": [
                { "Name": "UserTypeSelector", "Hide": true },
                { "Name": "DisableUser", "Hide": true },
                { "Name": "RevokeAccess", "Hide": true },
                { "Name": "ChangeLicensesSelector", "Hide": true },
                { "Name": "ChangeGroupsSelector", "Hide": true },
                { "Name": "GroupToAdd", "Hide": true },
                { "Name": "GroupsToRemovePrefix", "Hide": true },
                { "Name": "CallerName", "Hide": true }
            ]
        }
    }
}
```

Meaning of the settings:

- `userTypeRestriction`: `0` allows all user types, `1` members only, `2` guests only. A mismatching user stops the run before any change.
- `deleteUser`: delete the account (`true`) or keep it (`false`).
- `disableUser`, `revokeAccess`: block sign-in and end the user's sessions.
- `exportGroupMemberships`: export the group memberships to the report storage account (see `RJReport.StorageAccount`) and return a download link before groups and licenses are changed.
- `licensesMode`: `0` keeps the directly assigned licenses, `2` removes all of them.
- `groupsMode`: `0` keeps the groups, `1` removes the groups starting with `groupsToRemovePrefix`, `2` removes all groups. Both `1` and `2` add or keep `groupToAdd`.
- `replaceManagerReferences`, `replaceSponsorReferences`: hand the user's direct reports and sponsorships over to the replacement person.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All
  - GroupMember.ReadWrite.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when exportGroupMemberships is used)

### RBAC roles
- User Administrator
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserTypeSelector
Runs only for the chosen user type: all users, members only or guests only. With a mismatch the run stops before any change.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### DeleteUser
Delete removes the user object. Keep leaves the account in place; what happens to it follows the other switches.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### DisableUser
Blocks the account from signing in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### RevokeAccess
Ends the user's active sessions and invalidates their refresh tokens.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### exportGroupMemberships
Exports the user's group memberships to a file and returns a download link before groups and licenses are changed. Taken from the tenant setting OffboardUserPermanently.exportGroupMemberships.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the export is uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | user-leaver-groupmemberships |
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

### ChangeLicensesSelector
Remove all takes away every directly assigned license; licenses inherited from groups stay.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### ChangeGroupsSelector
Remove groups with the prefix removes the groups named by the prefix, Remove all groups removes every group. Both add or keep the group under "Group to add or keep". Dynamic, role-assignable and on-premises groups are skipped and listed.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### GroupToAdd
Group the user still needs after offboarding, for example a leaver license group. It is added if missing and never removed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsToRemovePrefix
Groups whose name starts with this text are removed, for example LIC_ for all license groups. Only used with "Remove groups with the prefix".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RevokeGroupOwnership
Remove or replace takes the user's group ownerships away. Where this user is the last owner, the replacement takes over; without a replacement the group is listed for manual follow-up. Keep leaves the ownerships as they are.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ManagerAsReplacementOwner
Takes the user's manager from Entra ID as the replacement owner, manager and sponsor. If a manager is set, it is used instead of the "Replacement person".

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ReplacementOwnerName
Person who takes over ownerships, direct reports and sponsorships when the manager is not used or this user has none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReplaceManagerReferences
Sets the replacement as manager of everyone who reports to this user. Without a replacement, those users are only listed.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ReplaceSponsorReferences
Replaces this user as sponsor wherever they are set as one, typically on guest users. Without a replacement, those users are only listed. Sponsorships held through a group stay. This scans all users of the tenant.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

