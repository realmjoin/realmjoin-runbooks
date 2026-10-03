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
