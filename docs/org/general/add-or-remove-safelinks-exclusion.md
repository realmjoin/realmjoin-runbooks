# Add Or Remove Safelinks Exclusion

Allow a URL pattern in a Safe Links policy or remove it

## Detailed description
Adds a URL pattern to the exclusions of a Microsoft Defender Safe Links policy so links matching it are no longer rewritten, or removes such an exclusion. It can also list the existing policies with their settings, and create a policy with its assignment group when the requested one does not exist.

## Where to find
Org \ General \ Add Or Remove Safelinks Exclusion

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### Action
Add puts the pattern on the exclusion list, Remove takes it off, List shows the policies and their settings.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | false |
| Type | Int32 |

### LinkPattern
Pattern to exclude; * works as a wildcard for host and path, for example https://*.microsoft.com/*.

| Property | Value |
|----------|-------|
| Default Value | https://*.microsoft.com/* |
| Required | false |
| Type | String |

### DefaultPolicyName
Policy used when no policy name is given.

| Property | Value |
|----------|-------|
| Default Value | Default SafeLinks Policy |
| Required | true |
| Type | String |

### PolicyName
Policy to change. Leave empty to use the default policy.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateNewPolicyIfNeeded
Creates the Safe Links policy and its assignment group when it does not exist yet.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

