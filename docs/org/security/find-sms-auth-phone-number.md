# Find SMS Auth Phone Number

Find the user who holds an SMS sign-in phone number

## Detailed description
Finds the user who has a given phone number registered for SMS sign-in in Entra ID. Such numbers must be unique in the tenant, so registering the same number for another user fails until the first registration is removed. Nothing is changed.

## Where to find
Org \ Security \ Find SMS Auth Phone Number

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### PhoneNumber
Number in international format without spaces, for example +492349876543.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

