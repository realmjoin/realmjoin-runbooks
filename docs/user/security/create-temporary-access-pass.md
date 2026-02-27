# Create Temporary Access Pass

Create a temporary access pass for a user

## Detailed description
Creates a new Temporary Access Pass (TAP) authentication method for a user in Microsoft Entra ID. Existing TAPs for the user are removed before creating a new one.

## Where to find
User \ Security \ Create Temporary Access Pass

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.ReadWrite.All


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### LifetimeInMinutes
Lifetime of the temporary access pass in minutes.

| Property | Value |
|----------|-------|
| Default Value | 240 |
| Required | false |
| Type | Int32 |

### OneTimeUseOnly
If set to true, the pass can be used only once.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

