# Get Teams Phone Number Assignment

Check whether a phone number is assigned in Microsoft Teams

## Detailed description
Looks up whether a phone number is assigned to a user in Microsoft Teams. If it is, the user and their voice policies are shown. Nothing is changed.

## Where to find
Org \ Phone \ Get Teams Phone Number Assignment

## Additional documentation
If a Teams user is found for the phone number, the following details are displayed:
- Display name
- User principal name
- Account type
- Phone number type
- Online voice routing policy
- Calling policy
- Dial plan
- Tenant dial plan

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All

### RBAC roles
- Teams Administrator


## Parameters
### PhoneNumber
Number in international format without spaces, for example +49321987654, optionally with an extension as +49321987654;ext=123.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

