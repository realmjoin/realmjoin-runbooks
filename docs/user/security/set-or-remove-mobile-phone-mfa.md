# Set Or Remove Mobile Phone Mfa

Set or remove a user's mobile phone MFA method

## Detailed description
Adds, updates, or removes the user's mobile phone authentication method. If you need to change a number, remove the existing method first and then add the new number.

## Where to find
User \ Security \ Set Or Remove Mobile Phone Mfa

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

### phoneNumber
Mobile phone number in international E.164 format (e.g., +491701234567).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Remove
"Set/Update Mobile Phone MFA Method" (final value: $false) or "Remove Mobile Phone MFA Method" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the mobile phone MFA method for the user. If set to false, it will add or update the mobile phone MFA method with the provided phone number.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)

