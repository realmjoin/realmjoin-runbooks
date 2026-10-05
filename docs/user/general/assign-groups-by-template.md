# Assign Groups By Template

Add this user to a predefined set of groups

## Detailed description
Adds this user to one or more Entra ID groups. The groups come from a template that an administrator defines in the runbook customization, so the person running it picks a template instead of individual groups.

## Where to find
User \ General \ Assign Groups By Template

## Define the templates via runbook customization

The templates the users can pick are defined once per tenant in the runbook customization. Each template presets the group list (`GroupsString`); `UseDisplaynames` decides whether that list holds object IDs (`false`) or display names (`true`).

```json
{
    "Templates": {
        "Options": [
            {
                "$id": "GroupsTemplates",
                "$values": [
                    {
                        "Display": "User template 1 (object IDs)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "c1f8e69f-e6c0-4e7e-b49d-241046958aa3,98c19df0-0bc1-4236-92b9-12559e1127d3"
                            }
                        }
                    },
                    {
                        "Display": "User template 2 (display names)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Microsoft VC Redistributable 2013"
                            }
                        }
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-user_general_assign-groups-by-template": {
            "ParameterList": [
                {
                    "Name": "GroupsTemplate",
                    "Select": {
                        "Options": {
                            "$ref": "GroupsTemplates"
                        }
                    }
                },
                {
                    "Name": "UseDisplaynames",
                    "Default": false
                }
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### UserId
Object ID of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupsTemplate
Template that decides which groups the user joins. The available templates are set up in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsString
Groups to add the user to, separated by commas. Usually filled in by the selected template.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UseDisplaynames
Whether the group list contains display names instead of object IDs. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

