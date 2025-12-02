# Create Temporary Access Pass

Create an AAD temporary access pass for a user.

## Detailed description
Create an AAD temporary access pass for a user.

## Where to find
User \ Security \ Create Temporary Access Pass

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.ReadWrite.All


## Parameters
### UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### LifetimeInMinutes
Time the pass will stay valid in minutes

| Property | Value |
|----------|-------|
| Default Value | 240 |
| Required | false |
| Type | Int32 |

### OneTimeUseOnly

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

