# Enable Or Disable Password Expiration

Enable or disable password expiration for a user

## Detailed description
Updates the password policy for a user in Microsoft Entra ID. This can be used to disable password expiration or re-enable the default expiration behavior.

## Where to find
User \ Security \ Enable Or Disable Password Expiration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisablePasswordExpiration
If set to true, disables password expiration for the user.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

