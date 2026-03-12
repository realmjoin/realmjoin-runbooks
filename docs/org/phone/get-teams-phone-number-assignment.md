# Get Teams Phone Number Assignment

Check whether a phone number is assigned in Microsoft Teams

## Detailed description
Looks up whether a given phone number is assigned to a user in Microsoft Teams. If the phone number is assigned, information about the user and relevant voice policies is returned.

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
The phone number must be in E.164 format. Example: +49321987654 or +49321987654;ext=123. It must start with a '+' followed by the country code and subscriber number, with an optional ';ext=' followed by the extension number, without spaces or special characters.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

