# Remove Group

Delete this group and its Microsoft 365 resources

## Detailed description
Deletes this group. For a Microsoft 365 group this also removes the Teams team and the SharePoint site that belong to it, including their content. The group and its content can be restored from the deleted groups for 30 days, after that they are gone.

## Where to find
Group \ General \ Remove Group

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

