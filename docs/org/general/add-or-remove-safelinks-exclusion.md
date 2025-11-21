# Add Or Remove Safelinks Exclusion

Add or remove a SafeLinks URL exclusion to/from a given policy.

## Detailed description
Add or remove a SafeLinks URL exclusion to/from a given policy.
It can also be used to initially create a new policy if required.

## Where to find
Org \ General \ Add Or Remove Safelinks Exclusion

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### Action

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### LinkPattern
URL to allow, can contain '*' as wildcard for host and paths

| Property | Value |
|----------|-------|
| Default Value | https://*.microsoft.com/* |
| Required | false |
| Type | String |

### DefaultPolicyName
If only one policy exists, no need to specify. Will use "DefaultPolicyName" as default otherwise.

| Property | Value |
|----------|-------|
| Default Value | Default SafeLinks Policy |
| Required | true |
| Type | String |

### PolicyName
Optional, will overwrite default values

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateNewPolicyIfNeeded

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

