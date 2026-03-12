# Change Visibility

Change a group's visibility

## Detailed description
This runbook changes the visibility of a Microsoft 365 group between Private and Public.
Set the Public switch to make the group public; otherwise it will be set to private.
This does not change group membership, owners, or email addresses.

## Where to find
Group \ General \ Change Visibility

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All


## Parameters
### GroupID
Object ID of the target group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Public
"Make group private" (final value: $false) or "Make group public" (final value: $true) can be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

