# List Users By MFA Methods Count

Reports users by the count of their registered MFA methods.

## Detailed description
This Runbook retrieves a list of users from Azure AD and counts their registered MFA authentication methods.
As a dropdown for the MFA methods count range, you can select from "0 methods (no MFA)", "1-3 methods", "4-5 methods", or "6+ methods".
The output includes the user display name, user principal name, and the count of registered MFA methods.

## Where to find
Org \ Security \ List Users By MFA Methods Count

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### mfaMethodsRange
Range for filtering users based on the count of their registered MFA methods.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

