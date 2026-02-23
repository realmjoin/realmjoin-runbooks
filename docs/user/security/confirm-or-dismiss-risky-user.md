# Confirm Or Dismiss Risky User

Confirm compromise or dismiss a risky user

## Detailed description
Confirms a user compromise or dismisses a risky user entry using Microsoft Entra ID Identity Protection. This helps security teams remediate and track risky sign-in events.

## Where to find
User \ Security \ Confirm Or Dismiss Risky User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - IdentityRiskyUser.ReadWrite.All


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Dismiss
"Confirm compromise" (final value: $false) or "Dismiss risk" (final value: $true) can be selected as action to perform. If set to true, the runbook will attempt to dismiss the risky user entry for the target user. If set to false, it will attempt to confirm a compromise for the target user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

