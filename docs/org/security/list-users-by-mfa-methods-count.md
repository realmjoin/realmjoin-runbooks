# List Users By MFA Methods Count

List users by how many MFA methods they registered

## Detailed description
Counts the registered authentication methods of every enabled user and lists the users whose count falls into the chosen range, for example those with no MFA method at all. The list shows display name, sign-in name and the number of methods. Nothing is changed.

## Where to find
Org \ Security \ List Users By MFA Methods Count

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### mfaMethodsRange
No methods lists users without any registered method; the other ranges list users with that many registered methods.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)

