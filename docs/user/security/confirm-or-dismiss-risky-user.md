# Confirm Or Dismiss Risky User

Confirm this user as compromised or dismiss the risk

## Detailed description
Tells Microsoft Entra ID Protection what to do with the risk flagged on this user. Confirm compromise marks the account as compromised, which sets the user risk to high. Dismiss risk clears the flag when the activity was legitimate.

## Where to find
User \ Security \ Confirm Or Dismiss Risky User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - IdentityRiskyUser.ReadWrite.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Dismiss
Confirm compromise marks the account as compromised. Dismiss risk clears the risk flag.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

