# Assign Groups By Template

Add this device to a predefined set of groups

## Detailed description
Adds this device to one or more Entra ID groups. The groups come from a template that an administrator defines in the runbook customization, so the person running it picks a template instead of individual groups.

## Where to find
Device \ General \ Assign Groups By Template

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - Group.Read.All
  - GroupMember.ReadWrite.All


## Parameters
### DeviceId
Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupsTemplate
Template that decides which groups the device joins. The available templates are set up in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupsString
Groups to add the device to, separated by commas. Usually filled in by the selected template.

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

