# Enable Or Disable External Mail

Enable or disable external parties to send emails to a Microsoft 365 group

## Detailed description
This runbook configures whether external senders are allowed to email a Microsoft 365 group.
It uses Exchange Online to enable or disable the RequireSenderAuthenticationEnabled setting.
You can also query the current state without making changes.

## Where to find
Group \ Mail \ Enable Or Disable External Mail

## Notes
Setting this via Microsoft Graph is broken as of 2021-06-28.
Attribute: allowExternalSenders.
See https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property.

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### GroupId
Object ID of the Microsoft 365 group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
"Enable External Mail" (final value: 0), "Disable External Mail" (final value: 1) or "Query current state only" (final value: 2) can be selected as action to perform. If set to 0, the runbook will allow external senders to email the group. If set to 1, it will block external senders from emailing the group. If set to 2, it will return whether external mailing is currently enabled or disabled for the group without making any changes.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

