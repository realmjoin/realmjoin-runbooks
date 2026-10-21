# Enable Or Disable External Mail

Allow or block external senders for this Microsoft 365 group

## Detailed description
Controls whether people outside the organization can send email to this Microsoft 365 group. The current setting can also be shown without changing it.

## Where to find
Group \ Mail \ Enable Or Disable External Mail

## Implementation notes

The setting is changed through Exchange Online (`RequireSenderAuthenticationEnabled`), not through Microsoft Graph. Writing the corresponding `allowExternalSenders` property of the group via Microsoft Graph is a documented known issue (as of 2021-06-28), see [Setting the allowExternalSenders property](https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property).


## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### GroupId
Object ID of the group the runbook acts on. Set by the portal from the selected group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
Allow lets external senders email the group. Block limits it to internal senders. Query only shows the current state.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

