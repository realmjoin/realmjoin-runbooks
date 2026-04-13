# Set Or Remove Mobile Phone Mfa

Set or remove a user's mobile phone MFA method

## Detailed description
Adds, updates, or removes the user's mobile phone authentication method. This runbook manages phone numbers as regular MFA factors (call/text verification). Important: The Microsoft Graph phoneMethods API does not offer a way to add a phone number as "MFA only" without triggering an automatic SMS Sign-In registration attempt. If the user is enabled by the tenant's Authentication Methods Policy for SMS Sign-In, Graph will automatically try to register the number for SMS Sign-In after creating or updating the phone method. If the number is already used by another user for SMS Sign-In, Graph returns a 409 Conflict with error code "phoneNumberNotUnique". However, the phone method itself (for regular MFA) is typically created or updated successfully despite this error. The smsSignInState property is read-only and cannot be controlled via the create/update request. SMS Sign-In can only be explicitly managed via the separate enableSmsSignIn and disableSmsSignIn endpoints. This runbook verifies the actual state after such errors and reports success if the MFA method was assigned, with a warning about the SMS Sign-In conflict. If the assignment truly failed, it searches for the user holding the number.

## Where to find
User \ Security \ Set Or Remove Mobile Phone Mfa

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - UserAuthenticationMethod.ReadWrite.All


## Parameters
### UserId
Object ID of the target user.

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

