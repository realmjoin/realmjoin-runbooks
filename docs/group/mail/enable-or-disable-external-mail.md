# Enable Or Disable External Mail

Enable/disable external parties to send eMails to O365 groups.

## Detailed description
Enable/disable external parties to send eMails to O365 groups.

## Where to find
Group \ Mail \ Enable Or Disable External Mail

## Notes
Notes: Setting this via graph is currently broken as of 2021-06-28:
 attribute: allowExternalSenders
 https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### GroupId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)

