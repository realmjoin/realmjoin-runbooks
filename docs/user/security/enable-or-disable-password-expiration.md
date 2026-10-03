# Enable Or Disable Password Expiration

Turn password expiration on or off for this user

## Detailed description
Sets whether the password of this user expires. Turning expiration off keeps the current password valid indefinitely, for example for service or shared accounts; turning it on restores the tenant's default expiration.

## Where to find
User \ Security \ Enable Or Disable Password Expiration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisablePasswordExpiration
Yes stops the password from expiring. No applies the tenant's default expiration again.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

