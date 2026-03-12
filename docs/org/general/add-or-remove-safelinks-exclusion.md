# Add Or Remove Safelinks Exclusion

Add or remove a SafeLinks URL exclusion from a policy

## Detailed description
Adds or removes a SafeLinks URL pattern exclusion in a specified policy. The runbook can also list existing policies and can create a new policy and group if needed.

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
"Add URL Pattern to Policy", "Remove URL Pattern from Policy" or "List all existing policies and settings" could be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### LinkPattern
URL pattern to allow; it can contain '*' as a wildcard for host and paths.

| Property | Value |
|----------|-------|
| Default Value | https://*.microsoft.com/* |
| Required | false |
| Type | String |

### DefaultPolicyName
Default SafeLinks policy name used when no explicit policy name is provided.

| Property | Value |
|----------|-------|
| Default Value | Default SafeLinks Policy |
| Required | true |
| Type | String |

### PolicyName
Optional SafeLinks policy name; if provided, it overrides the default selection.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateNewPolicyIfNeeded
If set to true, the runbook creates a new SafeLinks policy and assignment group when the requested policy does not exist.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

